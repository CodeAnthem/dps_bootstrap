#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-14 | Modified: 2025-10-17
# Description:   Script Library File
# Feature:       Formatting helper functions
# ==================================================================================================

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

console() { echo "${1:-}" >&2; }
logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "$1" "$2" >&2; }

log() { logDate "" "$1"; }
error() { logDate "❌" "$1"; exit 1; }
success() { logDate "✅" "$1"; }
debug() { if [[ "${DEBUG:-}" == "1" ]]; then logDate "🐛" "$1"; fi; }

# Visual separators
section_header() {
    local title="$1"
    printf "╭─────────────────────────────────────────────────────────────────────────────╮\n"
    printf "│ %-75s │\n" "$title"
    printf "╰─────────────────────────────────────────────────────────────────────────────╯\n"
}

step_start() {
    local step="$1"
    printf "\n🚀 %s...\n" "$step"
}

step_complete() {
    local step="$1"
    printf "✅ %s completed\n" "$step"
}

# Progress spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Clear to new section (like clear but keeps history)
new_section() {
    printf "\033[2J\033[H"
}
