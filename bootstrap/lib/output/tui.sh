#!/usr/bin/env bash
# lib/output/tui.sh
# Robust pure-bash TUI for Nix Deploy System
# - fixed header, scrollable body, footer progress
# - background tasks with ephemeral FIFOs (no persistent temp files)
# - coprocess-based control channel (no disk-based shared state)
# - safe Ctrl-C handling + guaranteed cleanup
#
# Usage:
#   source lib/output/tui.sh
#   tui::init "Title" "Subtitle"
#   idx=$(tui::body_append "Starting step X")
#   pid=$(tui::task_start "Label text" <command> arg1 arg2 ...)
#   tui::draw_progress done total
#   tui::shutdown

# -------------------------
# Globals
# -------------------------
declare -g TUI_TITLE=""
declare -g TUI_SUBTITLE=""
declare -g TUI_BODY_HEIGHT=0
declare -ga TUI_BODY_LINES=()
declare -g TUI_BODY_TOP=0
declare -g TUI_COLS=80
declare -g TUI_LINES=24

# coprocess handles
declare -ga TUI_COPROC=()      # the TICKER coproc array (populated at start)
declare -g TUI_COPROC_PID=0

# track local task metadata (parent side)
declare -gA TUI_TASK_IDX=()
declare -gA TUI_TASK_FIFO=()
declare -gA TUI_TASK_LABEL=()
declare -ga TUI_TASK_PIDS=()

# ticker spin chars
readonly TUI__SPIN_CHARS="/|\\-"

# safety: maximum lines to include when printing failed task output
readonly TUI__FAIL_TAIL_LINES=200

# -------------------------
# Terminal size helpers
# -------------------------
tui::get_term_size() {
    # prefer bash LINES/COLUMNS; enable checkwinsize to auto-update
    shopt -s checkwinsize >/dev/null 2>&1 || true
    TUI_LINES=${LINES:-24}
    TUI_COLS=${COLUMNS:-80}
    # fallback: attempt stty only if LINES/COLUMNS empty (most systems have stty)
    if [[ -z "$TUI_LINES" || -z "$TUI_COLS" ]] || (( TUI_LINES == 0 || TUI_COLS == 0 )); then
        if stty_size=$(stty size 2>/dev/null); then
            IFS=' ' read -r TUI_LINES TUI_COLS <<<"$stty_size"
        else
            TUI_LINES=24; TUI_COLS=80
        fi
    fi
    TUI_BODY_HEIGHT=$(( TUI_LINES - 2 ))
    (( TUI_BODY_HEIGHT < 1 )) && TUI_BODY_HEIGHT=1
}

# -------------------------
# Low-level primitives
# -------------------------
tui::move_row() { printf '\033[%d;1H' "$1" >&2; }
tui::clear_eol() { printf '\033[K' >&2; }
tui::hide_cursor() { printf '\033[?25l' >&2; }
tui::show_cursor() { printf '\033[?25h' >&2; }

tui::print_row() {
    local row="$1"; shift
    local text="${*:-}"
    tui::move_row "$row"
    # truncate or pad to terminal width
    if (( ${#text} > TUI_COLS )); then
        printf '%.*s' "$TUI_COLS" "$text" >&2
    else
        printf "%-${TUI_COLS}s" "$text" >&2
    fi
}

# -------------------------
# Header / Footer / Body
# -------------------------
tui::draw_header() {
    tui::move_row 1
    printf '\033[7m' >&2
    local head="  ${TUI_TITLE}"
    [[ -n "$TUI_SUBTITLE" ]] && head+=" — ${TUI_SUBTITLE}"
    printf "%-${TUI_COLS}s" "$head" >&2
    printf '\033[0m' >&2
}

tui::draw_footer() {
    local msg="${1:-Idle}"
    tui::move_row "$TUI_LINES"
    printf '\033[7m' >&2
    local left="  Press Ctrl-C to abort"
    local max_right=$(( TUI_COLS - ${#left} - 2 ))
    (( max_right < 0 )) && max_right=0
    [[ ${#msg} -gt max_right ]] && msg="${msg:0:max_right}"
    local pad=$(( TUI_COLS - ${#left} - ${#msg} ))
    (( pad < 0 )) && pad=0
    printf "%s%${pad}s%s" "$left" "" "$msg" >&2
    printf '\033[0m' >&2
}

tui::redraw_body() {
    local start=$TUI_BODY_TOP
    local row=2
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

tui::body_append() {
    local line="$*"
    TUI_BODY_LINES+=("$line")
    local idx=$(( ${#TUI_BODY_LINES[@]} - 1 ))
    if (( ${#TUI_BODY_LINES[@]} > TUI_BODY_HEIGHT )); then
        TUI_BODY_TOP=$(( ${#TUI_BODY_LINES[@]} - TUI_BODY_HEIGHT ))
    fi
    tui::redraw_body
    echo "$idx"
}

tui::body_replace() {
    local idx="$1"; shift
    local text="$*"
    TUI_BODY_LINES[$idx]="$text"
    tui::redraw_body
}

# -------------------------
# COPROC ticker (control pipe + draw loop)
# -------------------------
# The ticker coprocess reads commands sent by parent via >&"${TUI_COPROC[1]}".
# Commands:
#   ADD pid idx fifo base64_label
#   DONE pid status
#   OUT pid n   <then parent sends n lines immediately>
#   STOP

tui::_start_coproc_ticker() {
    # If already running, don't start twice
    if (( TUI_COPROC_PID > 0 )); then
        if kill -0 "$TUI_COPROC_PID" 2>/dev/null; then return 0; fi
    fi

    # Start coprocess; its stdin is parent's write end (TUI_COPROC[1]).
    coproc TUI_COPROC {
        # inside coproc
        declare -A _tk_label=()
        declare -A _tk_idx=()
        declare -A _tk_fifo=()
        declare -a _tk_pids=()
        local spin="/|\\-" pos=0
        local cmdline
        # non-blocking read loop with timeout to both handle commands and redraw
        while true; do
            # check for control command with timeout (120ms)
            if IFS= read -r -t 0.12 cmdline; then
                # parse command
                # Use default shell split: first word is type
                local cmd=$(printf '%s' "$cmdline" | awk '{print $1}')
                if [[ "$cmd" == "ADD" ]]; then
                    # Format: ADD pid idx fifo b64label
                    # use read to extract fields safely
                    local pid idx fifo b64
                    read -r _ _ pid idx fifo b64 <<<"$cmdline"
                    # decode label (base64 -> may contain spaces/newlines removed)
                    local label
                    if [[ -n "$b64" ]]; then
                        label=$(printf '%s' "$b64" | base64 --decode 2>/dev/null || printf '%s' "$b64")
                    else
                        label="task:$pid"
                    fi
                    _tk_label[$pid]="$label"
                    _tk_idx[$pid]="$idx"
                    _tk_fifo[$pid]="$fifo"
                    _tk_pids+=("$pid")
                    # initial line already appended by parent; ensure shown
                    # (no immediate rewrite needed; redraw loop will show spinner)
                elif [[ "$cmd" == "DONE" ]]; then
                    # DONE pid status
                    local _ _ pid status
                    read -r _ _ pid status <<<"$cmdline"
                    # find index in _tk_pids and remove
                    local new=() p
                    for p in "${_tk_pids[@]}"; do
                        if [[ "$p" == "$pid" ]]; then
                            # update body: success or fail placeholder; actual output may follow via OUT
                            if (( status == 0 )); then
                                local idx=${_tk_idx[$pid]:-0}
                                tui::body_replace "$idx" "✅ ${_tk_label[$pid]}"
                            else
                                local idx=${_tk_idx[$pid]:-0}
                                tui::body_replace "$idx" "❌ ${_tk_label[$pid]} — failed (see details below)"
                            fi
                            # do NOT remove mapping yet; we will remove when we process OUT (cleanup)
                            :
                        else
                            new+=("$p")
                        fi
                    done
                    _tk_pids=("${new[@]}")
                    # footer will be updated by redraw loop
                elif [[ "$cmd" == "OUT" ]]; then
                    # OUT pid n
                    local _ _ pid n
                    read -r _ _ pid n <<<"$cmdline"
                    # read n lines from stdin (parent will send them right after OUT command)
                    local i line
                    tui::body_append "---- Output of ${_tk_label[$pid]:-$pid} ----"
                    for ((i=0;i<n;i++)); do
                        if IFS= read -r line; then
                            tui::body_append "    $line"
                        else
                            break
                        fi
                    done
                    tui::body_append "---- End Output ----"
                    # remove any leftover mapping files (parent handles fifo removal)
                elif [[ "$cmd" == "STOP" ]]; then
                    # exit cleanly
                    break
                else
                    # unknown command - ignore
                    :
                fi
            fi

            # redraw spinner / footer
            pos=$(( (pos + 1) % ${#spin} ))
            local c=${spin:pos:1}
            # draw spinner for each tracked task
            for p in "${_tk_pids[@]}"; do
                local idx=${_tk_idx[$p]:-}
                local label=${_tk_label[$p]:-task:$p}
                if [[ -n "$idx" ]]; then
                    tui::body_replace "$idx" "⏳ $label [$c]"
                fi
            done
            tui::draw_footer "Running: ${#_tk_pids[@]}"
        done

        # cleanup before exit
        tui::draw_footer "Ticker stopped"
        exit 0
    }
    # store pid for later monitoring/termination (child pid is in TUI_COPROC_PID)
    TUI_COPROC_PID=${TUI_COPROC_PID:-${TUI_COPROC_PID}}
    # in coproc, bash sets COPROC_PID as the PID of the coprocess; map to our var
    # but array name is TUI_COPROC; get its PID:
    TUI_COPROC_PID=${TUI_COPROC_PID:-${TUI_COPROC_PID}}
    # actually, bash provides the pid in ${TUI_COPROC_PID}? Ensure we capture:
}

# wrapper to send a control-line to coproc
tui::_coproc_send() {
    local line="$*"
    if [[ -n "${TUI_COPROC[1]:-}" ]]; then
        printf '%s\n' "$line" >&"${TUI_COPROC[1]}" 2>/dev/null || true
    fi
}

tui::_coproc_stop() {
    if [[ -n "${TUI_COPROC[1]:-}" ]]; then
        tui::_coproc_send "STOP"
        # close parent's write end to coproc (causes child to exit if it's reading)
        exec {TUI_COPROC[1]}>&- 2>/dev/null || true
    fi
    # wait for coproc process
    if [[ -n "${TUI_COPROC_PID:-}" ]] && kill -0 "${TUI_COPROC_PID}" 2>/dev/null; then
        kill "${TUI_COPROC_PID}" 2>/dev/null || true
        wait "${TUI_COPROC_PID}" 2>/dev/null || true
    fi
    TUI_COPROC_PID=0
    TUI_COPROC=()
}

# -------------------------
# Task management (using ephemeral FIFOs)
# -------------------------
# Start a background task that writes stdout+stderr into a FIFO.
# We create an ephemeral FIFO (mktemp -> rm -> mkfifo) and start the command redirecting to it.
# Parent registers the pid + fifo, and notifies ticker via ADD.
# A monitor background job waits for pid to finish, collects tail lines from fifo and notifies ticker with DONE and OUT messages.
#
# Returns: PID of the background command (so caller may wait if desired)

tui::task_start() {
    local label="$1"; shift
    if [[ -z "$label" ]]; then label="task"; fi

    # create ephemeral FIFO path
    local tmpf
    tmpf=$(mktemp "${NDS_RUNTIME_DIR:-/tmp}/tui_fifo.XXXXXX") || tmpf="/tmp/tui_fifo.$RANDOM.$$"
    rm -f "$tmpf" 2>/dev/null || true
    mkfifo "$tmpf" 2>/dev/null || {
        # fallback: create a regular tempfile if mkfifo fails
        tmpf="${NDS_RUNTIME_DIR:-/tmp}/tui_fifo.$RANDOM.$$"
        : > "$tmpf"
    }

    # append body line and get idx
    local idx
    idx=$(tui::body_append "⏳ $label")

    # start the command, redirecting stdout+stderr to FIFO
    # run in a subshell so we can get the pid
    ( "$@" >"$tmpf" 2>&1 ) &
    local pid=$!

    # register locally
    TUI_TASK_IDX[$pid]="$idx"
    TUI_TASK_FIFO[$pid]="$tmpf"
    TUI_TASK_LABEL[$pid]="$label"
    TUI_TASK_PIDS+=("$pid")

    # send ADD to coproc (label base64 encoded)
    local b64label
    b64label=$(printf '%s' "$label" | base64 --wrap=0 2>/dev/null || printf '%s' "$label")
    tui::_coproc_send "ADD $pid $idx $tmpf $b64label"

    # start monitor: wait for pid, then collect result and notify coproc
    (
        wait "$pid"
        local status=$?
        # send DONE
        tui::_coproc_send "DONE $pid $status"
        # capture last N lines from fifo (non-blocking by waiting small time)
        # Read up to TUI__FAIL_TAIL_LINES last lines; we use tail if available
        local nlines=0
        if [[ -p "${TUI_TASK_FIFO[$pid]}" ]]; then
            # fifo still exists, try to read last lines safely with tail
            if command -v tail >/dev/null 2>&1; then
                # tail read requires the FIFO to be readable; open and read then close
                local tmpout
                tmpout=$(mktemp "${NDS_RUNTIME_DIR:-/tmp}/tui_taskout.XXXXXX") || tmpout="/tmp/tui_taskout.$RANDOM.$$"
                # read from fifo with timeout-ish: cat in background and kill if it hangs after a short delay
                ( timeout 2 cat "${TUI_TASK_FIFO[$pid]}" > "$tmpout" 2>/dev/null ) 2>/dev/null || {
                    # fallback: try simple cat (may block)
                    cat "${TUI_TASK_FIFO[$pid]}" > "$tmpout" 2>/dev/null || true
                }
                if [[ -f "$tmpout" ]]; then
                    # get tail lines count
                    if command -v tail >/dev/null 2>&1; then
                        tail -n "$TUI__FAIL_TAIL_LINES" "$tmpout" > "${tmpout}.tail" 2>/dev/null || cp -f "$tmpout" "${tmpout}.tail" 2>/dev/null || true
                        nlines=$(wc -l < "${tmpout}.tail" 2>/dev/null || echo 0)
                        if (( nlines > 0 )); then
                            tui::_coproc_send "OUT $pid $nlines"
                            # send lines
                            while IFS= read -r l; do
                                tui::_coproc_send "$l"
                            done < "${tmpout}.tail"
                        fi
                    fi
                    rm -f "$tmpout" "${tmpout}.tail" 2>/dev/null || true
                fi
            else
                # tail not available - try a quick cat and send up to a small number of lines
                local tmpout
                tmpout=$(mktemp "${NDS_RUNTIME_DIR:-/tmp}/tui_taskout.XXXXXX") || tmpout="/tmp/tui_taskout.$RANDOM.$$"
                cat "${TUI_TASK_FIFO[$pid]}" > "$tmpout" 2>/dev/null || true
                nlines=$(wc -l < "$tmpout" 2>/dev/null || echo 0)
                if (( nlines > 0 )); then
                    tui::_coproc_send "OUT $pid $nlines"
                    while IFS= read -r l; do
                        tui::_coproc_send "$l"
                    done < "$tmpout"
                fi
                rm -f "$tmpout" 2>/dev/null || true
            fi
        fi

        # cleanup fifo
        rm -f "${TUI_TASK_FIFO[$pid]}" 2>/dev/null || true
        unset TUI_TASK_FIFO[$pid]
        # remove pid from parent's list
        local newlist=() p
        for p in "${TUI_TASK_PIDS[@]}"; do
            [[ "$p" == "$pid" ]] || newlist+=("$p")
        done
        TUI_TASK_PIDS=("${newlist[@]}")
        return 0
    ) & disown

    # ensure coproc running
    tui::_start_coproc_ticker

    echo "$pid"
}

# -------------------------
# Synchronous spinner helper
# -------------------------
tui::run_with_spinner() {
    local label="$1"; shift
    local tmp="$(mktemp "${NDS_RUNTIME_DIR:-/tmp}/tui_sync.XXXXXX")"
    printf "⏳ %s" "$label" >&2
    ("$@" >"$tmp" 2>&1)
    local st=$?
    if (( st == 0 )); then
        printf "\r\033[K✅ %s\n" "$label" >&2
    else
        printf "\r\033[K❌ %s\n" "$label" >&2
        if [[ -f "$tmp" ]]; then
            tail -n 200 "$tmp" >&2
        fi
    fi
    rm -f "$tmp" 2>/dev/null || true
    return "$st"
}

# -------------------------
# Progress bar helper
# -------------------------
tui::draw_progress() {
    local done="$1" total="$2"
    (( total == 0 )) && total=1
    local pct=$(( (done * 100) / total ))
    local width=$(( TUI_COLS - 20 ))
    (( width < 10 )) && width=10
    local filled=$(( (width * pct) / 100 ))
    local empty=$(( width - filled ))
    local bar
    bar="$(printf '%*s' "$filled" '' | tr ' ' '#')"
    bar+="$(printf '%*s' "$empty" '' | tr ' ' '.')"
    tui::draw_footer "Progress: ${pct}% [${bar}]"
}

# -------------------------
# Init / shutdown
# -------------------------
tui::init() {
    TUI_TITLE="${1:-}"
    TUI_SUBTITLE="${2:-}"
    tui::get_term_size
    printf '\033[2J\033[H' >&2
    tui::hide_cursor
    tui::draw_header
    tui::draw_footer "Idle"
    tui::redraw_body

    # ensure coproc exists lazily only when needed; register safety traps
    trap 'tui::shutdown; exit 130' INT TERM
    trap 'tui::on_resize' WINCH
}

tui::on_resize() {
    tui::get_term_size
    tui::draw_header
    tui::draw_footer "Resized"
    tui::redraw_body
}

tui::shutdown() {
    # stop coproc/ticker
    tui::_coproc_stop
    # attempt to kill running tasks (best-effort) and remove FIFOs
    for pid in "${TUI_TASK_PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
        [[ -n "${TUI_TASK_FIFO[$pid]:-}" ]] && rm -f "${TUI_TASK_FIFO[$pid]}" 2>/dev/null || true
    done
    tui::show_cursor
    tui::move_row $(( TUI_LINES + 1 ))
    printf "\n" >&2
}

# Emergency fallback to restore terminal if something went terribly wrong.
# This trap ensures the cursor is visible again on EXIT.
trap 'tui::show_cursor; stty sane 2>/dev/null || true' EXIT

# end of tui.sh
