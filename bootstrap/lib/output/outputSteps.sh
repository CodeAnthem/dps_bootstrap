#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-11-06
# Description:   Step progress helpers and spinner for long-running tasks
# Feature:       step_start / step_complete / step_fail and show_spinner
# ==================================================================================================

# Global to hold current step text
declare -g NDS_CURRENT_STEP_NAME=""

# ------------------------------------------------------------------------------
# Start a step (prints message and leaves cursor on same line)
# Usage: nds_step_start "Doing something..."
# ------------------------------------------------------------------------------
step_start() {
    local message="${1:-}"
    NDS_CURRENT_STEP_NAME="$message"
    # Print without newline so subsequent spinner or blocking process is on same line
    printf "⏳ %s" "$message" >&2
}

# ------------------------------------------------------------------------------
# Complete a step successfully
# Usage: nds_step_complete "Completed message (optional)"
# ------------------------------------------------------------------------------
step_complete() {
    local message="${1:-$NDS_CURRENT_STEP_NAME}"
    # Carriage return + clear line then print success
    printf "\r\033[K✅ %s\n" "$message" >&2
    NDS_CURRENT_STEP_NAME=""
}

# ------------------------------------------------------------------------------
# Run a command with a spinner
# Usage: nds_run_with_spinner "Message" "command args..."
# ------------------------------------------------------------------------------
step_animated() {
    local message="$1"
    shift
    step_start "$message"
    ("$@") & pid=$!
    nds_show_spinner "$pid"
    if wait "$pid"; then
        step_complete "$message"
        return 0
    else
        step_fail "$message"
        return 1
    fi
}


# ------------------------------------------------------------------------------
# Fail a step
# Usage: nds_step_fail "Failed message (optional)"
# ------------------------------------------------------------------------------
step_fail() {
    local message="${1:-$NDS_CURRENT_STEP_NAME}"
    printf "\r\033[K❌ %s\n" "$message" >&2
    NDS_CURRENT_STEP_NAME=""
}

# ------------------------------------------------------------------------------
# Show a spinner while a background PID is running
# Usage: nds_show_spinner <pid> [delaySeconds]
# Note: returns when PID no longer exists
# ------------------------------------------------------------------------------
nds_show_spinner() {
    local pid="${1:-}"
    local delay="${2:-0.1}"
    local spinChars="/|\\-"
    local i=0
    local char

    if [[ -z "$pid" ]]; then
        debug "nds_show_spinner: missing pid"
        return 1
    fi

    # While process exists, display spinner
    while ps -p "$pid" > /dev/null 2>&1; do
        char="${spinChars:i%${#spinChars}:1}"
        printf " [%s]  " "$char" >&2
        sleep "$delay"
        # backspace over spinner and trailing spaces (6 chars printed including brackets/spaces)
        printf "\b\b\b\b\b\b" >&2
        ((i++))
    done

    # Clean up leftover spinner area
    printf "    \b\b\b\b" >&2
    return 0
}
