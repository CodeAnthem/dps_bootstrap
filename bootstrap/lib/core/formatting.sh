#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Formatting and logging helper functions
# ==================================================================================================

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Output to console (stderr)
# Usage: console "message"
console() { echo "${1:-}" >&2; }
consolef() { printf "%s\n" "${1:-}" >&2; }

# Newline
newline() { echo >&2; }

# Log with timestamp
# Usage: logDate "prefix" "message"
logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "${1:-"  "}" "$2" >&2; }

# Standard logging functions
log() {
    logDate "" "$1"
    if declare -f nds_install_log &>/dev/null; then
        nds_install_log "$1"
    fi
}
info() { logDate "$(nds_ui_log_tag info)" "$1"; }
error() { logDate "$(nds_ui_log_tag error)" "$1"; }
fatal() { logDate "$(nds_ui_log_tag fatal)" "$1"; }
success() { logDate "$(nds_ui_log_tag success)" "$1"; }
debug() { [[ "${DEBUG:-0}" == "1" ]] && logDate "$(nds_ui_log_tag debug)" "$1" || true; }
warn() { logDate "$(nds_ui_log_tag warn)" "$1"; }
validation_error() { logDate "$(nds_ui_log_tag validation)" "$1"; }

# =============================================================================
# VISUAL FORMATTING FUNCTIONS
# =============================================================================

# Draw a box with title
# Usage: draw_title "title" [length]
draw_title() {
    nds_ui_draw_box "$1" "${2:-100}"
}

# Section header (small box)
# Usage: section_header "title"
section_header() { new_section; draw_title "  $1" 50; }

# Section title (large box with clear)
# Usage: section_title "title"
section_title() {
    new_section
    draw_title " === $1 === " 100
}

# Clear screen (keeps history)
# Usage: new_section
new_section() { printf "\033[2J\033[H" >&2; }

# =============================================================================
# PROGRESS INDICATORS
# =============================================================================

# Global variable to track step state
declare -g CURRENT_STEP_NAME=""

# Start a step with spinner
# Usage: step_start "message"
step_start() {
    local message="$1"
    CURRENT_STEP_NAME="$message"
    printf "%s %s" "$(nds_ui_step_icon start)" "$message" >&2
}

# Complete a step successfully
# Usage: step_complete "message"
step_complete() {
    local message="${1:-$CURRENT_STEP_NAME}"
    printf "\r\033[K%s %s\n" "$(nds_ui_step_icon ok)" "$message" >&2
    CURRENT_STEP_NAME=""
}

# Fail a step
# Usage: step_fail "message"
step_fail() {
    local message="${1:-$CURRENT_STEP_NAME}"
    printf "\r\033[K%s %s\n" "$(nds_ui_step_icon fail)" "$message" >&2
    CURRENT_STEP_NAME=""
}

# Show spinner while process runs
# Usage: show_spinner <pid>
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
