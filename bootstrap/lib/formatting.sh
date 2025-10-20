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
logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "${1:-"  "}" "$2" >&2; }

log() { logDate "" "$1"; }
error() { logDate "❌" "$1"; exit 1; }
success() { logDate "✅" "$1"; }
debug() { if [[ "${DEBUG:-}" == "1" ]]; then logDate "🐛" "$1"; fi; }

# Visual separators
draw_title() {
    local title="$1"
    local length="${2:-100}"  # default to 100 if not provided

    # The border is length - 2 (for the corner chars)
    local inner_length=$((length - 2))
    local border
    border=$(printf '─%.0s' $(seq 1 "$inner_length"))

    # Clear screen and print box
    printf "╭%s╮\n" "$border" >&2
    printf "│%-*s│\n" "$inner_length" "$title" >&2
    printf "╰%s╯\n" "$border" >&2
}


section_header() { draw_title "  $1" 50; }

section_title() {
    new_section
    draw_title " === $1 === " 100
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
new_section() { printf "\033[2J\033[H" >&2; }
