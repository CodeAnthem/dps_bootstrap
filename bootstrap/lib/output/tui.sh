#!/usr/bin/env bash
# ===========================================
# Nix Deploy System - Pure Bash TUI Framework
# ===========================================
# Provides a lightweight TUI with:
# - Fixed header (title + subtitle)
# - Scrollable body
# - Footer (progress bar / info)
# - Background tasks with spinner & capture
# - Clean Ctrl-C handling
# - No external dependencies (ANSI only)
# -------------------------------------------

# Globals
declare -g TUI_TITLE=""
declare -g TUI_SUBTITLE=""
declare -g TUI_BODY_HEIGHT=0
declare -ga TUI_BODY_LINES=()
declare -g TUI_BODY_TOP=0
declare -g TUI_TICKER_PID=0
declare -g TUI_SPINPOS=0
declare -ga TUI_RUNNING_PIDS=()
declare -gA TUI_TASK_PID_TO_IDX=()
declare -gA TUI_TASK_PID_TO_LABEL=()
declare -gA TUI_TASK_PID_TO_TMP=()
declare -gA TUI_TASK_PID_TO_STATUS=()

# --------------- Core Helpers ----------------

_tui_escape() { printf '\033[%s' "$1"; }

tui::get_term_size() {
    # Use bash's LINES/COLUMNS if available
    shopt -s checkwinsize
    if [[ -z "${LINES:-}" || -z "${COLUMNS:-}" ]]; then
        LINES=${LINES:-24}
        COLUMNS=${COLUMNS:-80}
    fi
    TUI_BODY_HEIGHT=$(( LINES - 2 ))
    (( TUI_BODY_HEIGHT < 1 )) && TUI_BODY_HEIGHT=1
}

# Move cursor to row (1-based)
tui::move_row() { printf '\033[%d;1H' "$1" >&2; }

# Hide/Show cursor
tui::hide_cursor() { printf '\033[?25l' >&2; }
tui::show_cursor() { printf '\033[?25h' >&2; }

# Print padded text at given row
tui::print_row() {
    local row="$1"; shift
    local text="${*:-}"
    tui::move_row "$row"
    printf "%-${COLUMNS}s" "${text:0:$COLUMNS}" >&2
}

# --------------- Header / Footer ---------------

tui::draw_header() {
    tui::move_row 1
    printf '\033[7m' >&2
    local head="  ${TUI_TITLE}"
    [[ -n "$TUI_SUBTITLE" ]] && head+=" — ${TUI_SUBTITLE}"
    printf "%-${COLUMNS}s" "$head" >&2
    printf '\033[0m' >&2
}

tui::draw_footer() {
    local msg="${1:-Idle}"
    tui::move_row "$LINES"
    printf '\033[7m' >&2
    local left="  Press Ctrl-C to abort"
    local max_right=$(( COLUMNS - ${#left} - 2 ))
    [[ $max_right -lt 0 ]] && max_right=0
    [[ ${#msg} -gt $max_right ]] && msg="${msg:0:$max_right}"
    local pad=$(( COLUMNS - ${#left} - ${#msg} ))
    (( pad < 0 )) && pad=0
    printf "%s%${pad}s%s" "$left" "" "$msg" >&2
    printf '\033[0m' >&2
}

# --------------- Body Buffer -------------------

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

# --------------- Shared File State --------------

_tui_running_file() { echo "${NDS_RUNTIME_DIR:-/tmp}/tui_running_pids"; }
_tui_label_file()   { echo "${NDS_RUNTIME_DIR:-/tmp}/tui_label_${1}"; }
_tui_index_file()   { echo "${NDS_RUNTIME_DIR:-/tmp}/tui_index_${1}"; }

_tui_register_pid() {
    local pid="$1" idx="$2" label="$3"
    echo "$pid" >> "$(_tui_running_file)"
    echo "$label" > "$(_tui_label_file "$pid")"
    echo "$idx"   > "$(_tui_index_file "$pid")"
}

_tui_unregister_pid() {
    local pid="$1"
    local tmp="$(_tui_running_file)"
    if [[ -f "$tmp" ]]; then
        grep -v -x "$pid" "$tmp" > "${tmp}.new" 2>/dev/null || true
        mv -f "${tmp}.new" "$tmp" 2>/dev/null || true
    fi
    rm -f "$(_tui_label_file "$pid")" "$(_tui_index_file "$pid")" 2>/dev/null || true
}

# --------------- Spinner Ticker ----------------

tui::start_ticker() {
    if (( TUI_TICKER_PID > 0 )) && kill -0 "$TUI_TICKER_PID" 2>/dev/null; then
        return 0
    fi

    >"$(_tui_running_file)" 2>/dev/null || true

    (
        local spin="/|\\-" pos=0
        while true; do
            sleep 0.12
            pos=$(( (pos + 1) % 4 ))
            mapfile -t pids < <(awk 'NF{print $0}' "$(_tui_running_file)" 2>/dev/null || true)
            local count=0
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    local label idx
                    label=$(<"$(_tui_label_file "$pid")" 2>/dev/null || echo "$pid")
                    idx=$(<"$(_tui_index_file "$pid")" 2>/dev/null || echo 0)
                    local s="${spin:$pos:1}"
                    tui::body_replace "$idx" "⏳ $label [$s]"
                    ((count++))
                fi
            done
            tui::draw_footer "Running: $count"
        done
    ) & disown
    TUI_TICKER_PID=$!
}

tui::stop_ticker() {
    if (( TUI_TICKER_PID > 0 )); then
        kill "$TUI_TICKER_PID" 2>/dev/null || true
        wait "$TUI_TICKER_PID" 2>/dev/null || true
        TUI_TICKER_PID=0
    fi
}

# --------------- Background Tasks ---------------

tui::task_start() {
    local label="$1"; shift
    local tmp="${NDS_RUNTIME_DIR:-/tmp}/tui_task_${RANDOM}.log"
    local idx pid

    idx=$(tui::body_append "⏳ $label")
    ("$@" >"$tmp" 2>&1) &
    pid=$!

    TUI_TASK_PID_TO_IDX[$pid]=$idx
    TUI_TASK_PID_TO_LABEL[$pid]="$label"
    TUI_TASK_PID_TO_TMP[$pid]="$tmp"
    TUI_TASK_PID_TO_STATUS[$pid]="running"
    TUI_RUNNING_PIDS+=("$pid")

    _tui_register_pid "$pid" "$idx" "$label"
    ( tui::_task_monitor "$pid" ) & disown

    tui::start_ticker
    echo "$pid"
}

tui::_task_monitor() {
    local pid="$1"
    wait "$pid"
    local status=$?
    local idx="${TUI_TASK_PID_TO_IDX[$pid]}"
    local label="${TUI_TASK_PID_TO_LABEL[$pid]}"
    local tmp="${TUI_TASK_PID_TO_TMP[$pid]}"
    _tui_unregister_pid "$pid"

    if (( status == 0 )); then
        tui::body_replace "$idx" "✅ $label"
        rm -f "$tmp" 2>/dev/null
    else
        tui::body_replace "$idx" "❌ $label — failed"
        if [[ -f "$tmp" ]]; then
            tui::body_append "---- Output of $label ----"
            tail -n 50 "$tmp" 2>/dev/null | while IFS= read -r line; do
                tui::body_append "    $line"
            done
            tui::body_append "---- End ----"
        fi
    fi
}

# --------------- Synchronous Spinner ------------

tui::run_with_spinner() {
    local label="$1"; shift
    local tmp="${NDS_RUNTIME_DIR:-/tmp}/tui_sync_${RANDOM}.log"
    printf "⏳ %s" "$label" >&2
    ("$@" >"$tmp" 2>&1)
    local status=$?
    if (( status == 0 )); then
        printf "\r\033[K✅ %s\n" "$label" >&2
    else
        printf "\r\033[K❌ %s\n" "$label" >&2
        tail -n 50 "$tmp" >&2
    fi
    rm -f "$tmp" 2>/dev/null
    return "$status"
}

# --------------- Progress Bar -------------------

tui::draw_progress() {
    local done="$1" total="$2"
    (( total == 0 )) && total=1
    local pct=$(( (done * 100) / total ))
    local width=$(( COLUMNS - 20 ))
    (( width < 10 )) && width=10
    local fill=$(( (width * pct) / 100 ))
    local bar
    bar="$(printf '%*s' "$fill" '' | tr ' ' '#')"
    bar+="$(printf '%*s' "$((width - fill))" '' | tr ' ' '.')"
    tui::draw_footer "Progress: ${pct}% [${bar}]"
}

# --------------- Init / Shutdown ----------------

tui::init() {
    TUI_TITLE="$1"
    TUI_SUBTITLE="$2"
    tui::get_term_size
    printf '\033[2J\033[H' >&2
    tui::hide_cursor
    tui::draw_header
    tui::draw_footer "Idle"
    tui::redraw_body
    trap 'tui::on_resize' WINCH
}

tui::on_resize() {
    tui::get_term_size
    tui::draw_header
    tui::draw_footer "Resized"
    tui::redraw_body
}

tui::shutdown() {
    tui::stop_ticker
    tui::show_cursor
    tui::move_row "$((LINES + 1))"
    printf "\n" >&2
}
