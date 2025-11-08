#!/usr/bin/env bash
# lib/output/tui.sh
# Minimal pure-bash TUI framework (header, scrollable body, footer progress,
# synchronous spinner tasks and background tasks that capture output).
#
# Requirements: bash (assoc arrays), `stty` (for terminal size). Uses ANSI escapes only.
# Writes UI to stderr (so it plays nicely with your existing logging helpers).

# -----------------------------
# Globals
# -----------------------------
declare -g TUI_TITLE=""
declare -g TUI_SUBTITLE=""
declare -g TUI_ROWS=0
declare -g TUI_COLS=0
declare -g TUI_BODY_HEIGHT=0
declare -ga TUI_BODY_LINES=()          # visible buffer lines (all appended lines)
declare -g TUI_BODY_TOP=0              # index of top visible line (0-based)
declare -g TUI_HIDE_CURSOR_ON_INIT=1
declare -g TUI_TICKER_PID=0
declare -gA TUI_TASK_PID_TO_IDX=()     # pid -> body line index
declare -gA TUI_TASK_PID_TO_TMP=()     # pid -> tmp file path (captured output)
declare -gA TUI_TASK_PID_TO_LABEL=()   # pid -> label
declare -gA TUI_TASK_PID_TO_STATUS=()  # pid -> running|success|fail
declare -ga TUI_RUNNING_PIDS=()
declare -g TUI_SPINPOS=0

# small helpers
_tui_escape() { printf '\033[%s' "$1"; } # convenience

# -----------------------------
# Terminal size (no tput)
# -----------------------------
tui::get_term_size() {
    # use stty size; fallback to 24x80
    local s
    if s=$(stty size 2>/dev/null); then
        IFS=' ' read -r TUI_ROWS TUI_COLS <<<"$s"
    else
        TUI_ROWS=24
        TUI_COLS=80
    fi
    # body height = rows minus 2 (header + footer)
    TUI_BODY_HEIGHT=$(( TUI_ROWS - 2 ))
    (( TUI_BODY_HEIGHT < 1 )) && TUI_BODY_HEIGHT=1
}

# -----------------------------
# Low-level screen primitives
# -----------------------------
# move cursor to specific row (1-based) and column 1
tui::move_row() { printf '\033[%d;1H' "$1" >&2; }

# clear to end of line
tui::clear_eol() { printf '\033[K' >&2; }

# hide/show cursor
tui::hide_cursor() { [[ "$TUI_HIDE_CURSOR_ON_INIT" -eq 1 ]] && printf '\033[?25l' >&2 || true; }
tui::show_cursor() { printf '\033[?25h' >&2; }

# print a padded line at given screen row (1-based)
# usage: tui::print_row <row> "<text>"
tui::print_row() {
    local row=$1; shift
    local text="${*:-}"
    tui::move_row "$row"
    # cut/pad to terminal width
    if (( ${#text} > TUI_COLS )); then
        printf '%.*s' "$TUI_COLS" "$text" >&2
    else
        printf "%-${TUI_COLS}s" "$text" >&2
    fi
}

# -----------------------------
# Draw static header & footer
# -----------------------------
tui::draw_header() {
    tui::move_row 1
    # inverse video header
    printf '\033[7m' >&2
    local headertext="  ${TUI_TITLE}"
    if [[ -n "$TUI_SUBTITLE" ]]; then
        headertext+=" — ${TUI_SUBTITLE}"
    fi
    printf "%-${TUI_COLS}s" "$headertext" >&2
    printf '\033[0m' >&2
}

# footer includes optional progress (percentage) string
# usage: tui::draw_footer "Progress: 34% [###....]"
tui::draw_footer() {
    local right="${1:-}"
    tui::move_row "$TUI_ROWS"
    printf '\033[7m' >&2
    # build left/right with space between
    local left="  Press Ctrl-C to abort"
    # if right too long, truncate
    local max_right=$(( TUI_COLS - ${#left} - 2 ))
    if (( max_right < 0 )); then max_right=0; fi
    if (( ${#right} > max_right )); then
        right="${right:0:max_right}"
    fi
    # pad so left + right fit
    local fill_len=$(( TUI_COLS - ${#left} - ${#right} ))
    (( fill_len < 0 )) && fill_len=0
    printf "%s%${fill_len}s%s" "$left" "" "$right" >&2
    printf '\033[0m' >&2
}

# -----------------------------
# Body management (scroll buffer)
# -----------------------------
# append a line to the body buffer and redraw visible area
# returns 0-based index of appended line
tui::body_append() {
    local line="$*"
    TUI_BODY_LINES+=("$line")
    local idx=$(( ${#TUI_BODY_LINES[@]} - 1 ))
    # auto-scroll to bottom
    if (( ${#TUI_BODY_LINES[@]} > TUI_BODY_HEIGHT )); then
        TUI_BODY_TOP=$(( ${#TUI_BODY_LINES[@]} - TUI_BODY_HEIGHT ))
    else
        TUI_BODY_TOP=0
    fi
    tui::redraw_body
    echo "$idx"
    return 0
}

# replace line at index and redraw
tui::body_replace() {
    local idx=$1; shift
    local text="$*"
    TUI_BODY_LINES[$idx]="$text"
    tui::redraw_body
}

# redraw body from TUI_BODY_TOP for TUI_BODY_HEIGHT lines
tui::redraw_body() {
    local start=$(( TUI_BODY_TOP ))
    local row=2  # body starts at row 2 (header=1)
    local i
    for ((i=0; i<TUI_BODY_HEIGHT; i++)); do
        local idx=$(( start + i ))
        if (( idx < ${#TUI_BODY_LINES[@]} )); then
            tui::print_row "$row" "${TUI_BODY_LINES[$idx]}"
        else
            tui::print_row "$row" ""
        fi
        ((row++))
    done
}

# -----------------------------
# Spinner & ticker (updates running tasks)
# -----------------------------
_tui_spinner_char() {
    local s="/|\\-"
    printf '%s' "${s:TUI_SPINPOS%${#s}:1}"
}

tui::start_ticker() {
    if (( TUI_TICKER_PID > 0 )) && kill -0 "$TUI_TICKER_PID" 2>/dev/null; then
        return 0
    fi

    ( 
      # ticker loop (backgrounded subshell)
      while true; do
        sleep 0.12
        # increment spinner position (shared var not accessible outside)
        TUI_SPINPOS=$(( (TUI_SPINPOS + 1) % 4 ))
        # redraw task lines
        for pid in "${TUI_RUNNING_PIDS[@]}"; do
            # if pid finished, skip
            if ! kill -0 "$pid" 2>/dev/null; then
                continue
            fi
            local idx="${TUI_TASK_PID_TO_IDX[$pid]}"
            local label="${TUI_TASK_PID_TO_LABEL[$pid]}"
            local spinner
            spinner=$(_tui_spinner_char)
            tui::body_replace "$idx" "⏳ $label [$spinner]"
        done
        # footer update: show simple running count
        tui::draw_footer "Running: ${#TUI_RUNNING_PIDS[@]}"
      done
    ) & disown
    TUI_TICKER_PID=$!
}

tui::stop_ticker() {
    if (( TUI_TICKER_PID > 0 )); then
        kill "$TUI_TICKER_PID" 2>/dev/null || true
        TUI_TICKER_PID=0
    fi
}

# -----------------------------
# Background task runner (captures output)
# -----------------------------
# usage: tui::task_start "Label" cmd args...
# returns pid; a body line is created tracking the task.
tui::task_start() {
    local label="$1"; shift
    local tmpfile
    if [[ -z "${NDS_RUNTIME_DIR:-}" ]]; then
        tmpfile="$(mktemp /tmp/tui_task.XXXXXX)" || tmpfile="/tmp/tui_task.$$"
    else
        tmpfile="${NDS_RUNTIME_DIR}/tui_task.$(date +%s%N).$$"
    fi

    # append initial placeholder line
    local idx
    idx=$(tui::body_append "⏳ $label")
    # start command in background, capture output
    ("$@" >"$tmpfile" 2>&1) &
    local pid=$!
    # register mapping
    TUI_TASK_PID_TO_IDX[$pid]=$idx
    TUI_TASK_PID_TO_TMP[$pid]=$tmpfile
    TUI_TASK_PID_TO_LABEL[$pid]="$label"
    TUI_TASK_PID_TO_STATUS[$pid]="running"
    TUI_RUNNING_PIDS+=("$pid")

    # start monitor in background to handle completion
    ( tui::_task_monitor "$pid" ) & disown

    # ensure ticker running
    tui::start_ticker

    echo "$pid"
    return 0
}

# internal monitor: wait for pid, mark success/fail, show captured output if failed
tui::_task_monitor() {
    local pid=$1
    wait "$pid"
    local status=$?
    local idx="${TUI_TASK_PID_TO_IDX[$pid]:-}"
    local tmp="${TUI_TASK_PID_TO_TMP[$pid]:-}"
    local label="${TUI_TASK_PID_TO_LABEL[$pid]:-}"
    # remove pid from running list
    local new_pids=()
    local p
    for p in "${TUI_RUNNING_PIDS[@]}"; do
        [[ "$p" == "$pid" ]] || new_pids+=("$p")
    done
    TUI_RUNNING_PIDS=("${new_pids[@]}")

    if (( status == 0 )); then
        TUI_TASK_PID_TO_STATUS[$pid]="success"
        # replace line with success, remove captured file to keep UI clean
        tui::body_replace "$idx" "✅ $label"
        # purge output to save space unless debug requested
        if [[ "${NDS_DEBUG:-0}" -eq 0 ]]; then
            rm -f "$tmp" 2>/dev/null || true
            unset TUI_TASK_PID_TO_TMP[$pid]
        fi
    else
        TUI_TASK_PID_TO_STATUS[$pid]="fail"
        # read captured output and append below (expand)
        local out
        if [[ -f "$tmp" ]]; then
            # append a header + output lines (limited to avoid huge dump)
            tui::body_replace "$idx" "❌ $label — failed (see details below)"
            tui::body_append "---- Output of: $label ----"
            # stream file lines (limit to last 200 lines)
            local tailcount=200
            if command -v tail >/dev/null 2>&1; then
                while IFS= read -r line; do tui::body_append "    $line"; done < <(tail -n "$tailcount" "$tmp")
            else
                while IFS= read -r line; do tui::body_append "    $line"; done < "$tmp"
            fi
            tui::body_append "---- End Output ----"
        else
            tui::body_replace "$idx" "❌ $label — failed (no captured output)"
        fi
    fi

    # update footer and redraw
    tui::draw_footer "Running: ${#TUI_RUNNING_PIDS[@]}"
    if (( ${#TUI_RUNNING_PIDS[@]} == 0 )); then
        tui::stop_ticker
    fi
}

# -----------------------------
# Simple synchronous spinner wrapper (compatible with existing step_animated)
# usage: tui::run_with_spinner "Label" cmd args...
# -----------------------------
tui::run_with_spinner() {
    local label="$1"; shift
    # print inline on stderr
    printf "⏳ %s" "$label" >&2
    ("$@" >"${NDS_RUNTIME_DIR:-/tmp}/tui_run_$$.out" 2>&1)
    local status=$?
    if (( status == 0 )); then
        printf "\r\033[K✅ %s\n" "$label" >&2
        return 0
    else
        printf "\r\033[K❌ %s\n" "$label" >&2
        # print captured output for debugging
        if [[ -f "${NDS_RUNTIME_DIR:-/tmp}/tui_run_$$.out" ]]; then
            sed -n '1,200p' "${NDS_RUNTIME_DIR:-/tmp}/tui_run_$$.out" >&2
        fi
        return $status
    fi
}

# -----------------------------
# Init / Shutdown
# -----------------------------
# usage: tui::init "Main title" "subtitle (optional)"
tui::init() {
    TUI_TITLE="${1:-}"
    TUI_SUBTITLE="${2:-}"
    tui::get_term_size
    tput_saved=$(stty -g 2>/dev/null) || tput_saved=""
    # make sure we restore state on exit - but we prefer to register a cleanup externally
    [[ "$TUI_HIDE_CURSOR_ON_INIT" -eq 1 ]] && tui::hide_cursor
    # draw static elements
    printf '\033[2J\033[H' >&2   # clear screen, keep scrollback
    tui::draw_header
    tui::draw_footer "Idle"
    tui::redraw_body

    # catch window resize
    trap 'tui::on_resize' SIGWINCH
}

tui::on_resize() {
    tui::get_term_size
    tui::draw_header
    tui::draw_footer "Resized"
    tui::redraw_body
}

# Call once at shutdown to restore cursor & clear ticker
tui::shutdown() {
    tui::stop_ticker
    tui::show_cursor
    # move cursor below UI so subsequent logs don't overwrite
    tui::move_row $(( TUI_ROWS + 1 ))
    printf "\n" >&2
}

# -----------------------------
# Progress bar helper (footer style)
# usage: tui::draw_progress overall_done overall_total
# -----------------------------
tui::draw_progress() {
    local done="$1"
    local total="$2"
    local pct=0
    (( total > 0 )) && pct=$(( (done * 100) / total ))
    local barwidth=$(( TUI_COLS - 20 ))
    (( barwidth < 10 )) && barwidth=10
    local filled=$(( (barwidth * pct) / 100 ))
    local empty=$(( barwidth - filled ))
    local bar
    bar="$(printf '%*s' "$filled" '' | tr ' ' '#')"
    bar+="$(printf '%*s' "$empty" '' | tr ' ' '.')"
    tui::draw_footer "Progress: ${pct}% [${bar}]"
}

# -----------------------------
# Minimal export API
# -----------------------------
# These functions are recommended to call from your framework:
#  - tui::init "Title" "Subtitle"
#  - tui::body_append "line"
#  - pid=$(tui::task_start "Task label" ...command...)
#  - tui::run_with_spinner "Label" command args...
#  - tui::draw_progress done total
#  - tui::shutdown

# end of tui.sh
