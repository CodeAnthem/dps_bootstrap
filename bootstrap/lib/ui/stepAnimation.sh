#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Step progress and spinner animation
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Install step lines, spinner, and nds_step_exec wrapper
# ==================================================================================================

declare -g CURRENT_STEP_NAME=""

nds_ui_step_icon() {
    local state="$1"
    nds_ui_init
    case "$state" in
        start) echo "..." ;;
        ok) echo "[OK]" ;;
        fail) echo "[FAIL]" ;;
    esac
}

step_start() {
    local message="$1"
    CURRENT_STEP_NAME="$message"
    printf '%s%s %s' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon start)" "$message" >&2
}

step_complete() {
    local message="${1:-$CURRENT_STEP_NAME}"
    printf '\r\033[K%s%s %s\n' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon ok)" "$message" >&2
    CURRENT_STEP_NAME=""
}

step_fail() {
    local message="${1:-$CURRENT_STEP_NAME}"
    printf '\r\033[K%s%s %s\n' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon fail)" "$message" >&2
    CURRENT_STEP_NAME=""
}

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr="|/-\\"
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr" >&2
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b" >&2
    done
    printf "    \b\b\b\b" >&2
}

# Description: Run a command with spinner; stdout/stderr go to the install detail log.
nds_step_exec() {
    local label="$1"
    shift
    local logfile="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local rc=0

    step_start "$label"
    {
        printf '\n=== %s ===\n' "$label"
        "$@"
    } >>"$logfile" 2>&1 &
    local pid=$!
    show_spinner "$pid"
    wait "$pid" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        step_complete "$label"
        return 0
    fi
    step_fail "$label"
    warn "Step failed — see $logfile for details"
    return "$rc"
}
