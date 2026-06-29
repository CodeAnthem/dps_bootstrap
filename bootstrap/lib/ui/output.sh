#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Console output and logging
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-06-29
# Description:   console(), log levels, sections, and step progress
# ==================================================================================================

console() { echo "${1:-}" >&2; }
consolef() { printf "%s\n" "${1:-}" >&2; }
newline() { echo >&2; }

logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "${1:-"  "}" "$2" >&2; }

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

draw_title() {
    nds_ui_draw_box "$1" "${2:-100}"
}

section_header() { new_section; draw_title "  $1" 50; }

section_title() {
    new_section
    draw_title " === $1 === " 100
}

new_section() { printf "\033[2J\033[H" >&2; }

declare -g CURRENT_STEP_NAME=""

step_start() {
    local message="$1"
    CURRENT_STEP_NAME="$message"
    printf "%s %s" "$(nds_ui_step_icon start)" "$message" >&2
}

step_complete() {
    local message="${1:-$CURRENT_STEP_NAME}"
    printf "\r\033[K%s %s\n" "$(nds_ui_step_icon ok)" "$message" >&2
    CURRENT_STEP_NAME=""
}

step_fail() {
    local message="${1:-$CURRENT_STEP_NAME}"
    printf "\r\033[K%s %s\n" "$(nds_ui_step_icon fail)" "$message" >&2
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
