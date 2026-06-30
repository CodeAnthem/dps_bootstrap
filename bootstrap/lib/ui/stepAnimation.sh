#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Step progress and spinner animation
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
# Description:   Install step lines, spinner, and nds_step_exec wrapper
# ==================================================================================================

declare -g CURRENT_STEP_NAME=""
declare -g CURRENT_STEP_START=0

# Description: Render the icon prefix for a step state.
# Arguments:
# - state: <String> start | ok | fail
# Returns:
# - <String> Fixed-width 5-char icon (colored when supported)
nds_ui_step_icon() {
    local state="$1"
    nds_ui_init
    case "$state" in
        start)
            printf '[   ]'
            ;;
        ok)
            if [[ "$NDS_UI_COLOR" == true ]]; then
                printf '\033[32m[OK]\033[0m'
            else
                printf '[OK]'
            fi
            ;;
        fail)
            if [[ "$NDS_UI_COLOR" == true ]]; then
                printf '\033[31m[FAIL]\033[0m'
            else
                printf '[FAIL]'
            fi
            ;;
    esac
}

step_start() {
    local message="$1"
    CURRENT_STEP_NAME="$message"
    CURRENT_STEP_START=$(date +%s)
    printf '%s%s %s' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon start)" "$message" >&2
}

step_complete() {
    local message="${1:-$CURRENT_STEP_NAME}"
    local elapsed=$(( $(date +%s) - ${CURRENT_STEP_START:-$(date +%s)} ))
    printf '\r\033[K%s%s %s  (%ds)\n' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon ok)" "$message" "$elapsed" >&2
    CURRENT_STEP_NAME=""
    CURRENT_STEP_START=0
}

step_fail() {
    local message="${1:-$CURRENT_STEP_NAME}"
    local elapsed=$(( $(date +%s) - ${CURRENT_STEP_START:-$(date +%s)} ))
    printf '\r\033[K%s%s %s  (%ds)\n' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon fail)" "$message" "$elapsed" >&2
    CURRENT_STEP_NAME=""
    CURRENT_STEP_START=0
}

# Description: Spinner that overwrites the step's icon slot until pid exits.
# Arguments:
# - pid:     <Int>    Background process id
# - message: <String> Step label to keep visible
show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.12
    local spinstr="|/-\\"
    local char
    while ps -p "$pid" > /dev/null 2>&1; do
        char="${spinstr:0:1}"
        printf '\r\033[K%s[%s%s] %s' "$NDS_UI_INDENT_B" "$char" "$char" "$message" >&2
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep "$delay"
    done
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
    show_spinner "$pid" "$label"
    wait "$pid" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        step_complete "$label"
        return 0
    fi
    step_fail "$label"
    warn "Step failed — see $logfile for details"
    return "$rc"
}
