#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Console output and logging
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-06-30
# Description:   console(), log levels, and section headers
# ==================================================================================================

console() { echo "${1:-}" >&2; }
consolef() { printf "%s\n" "${1:-}" >&2; }
newline() { echo >&2; }

logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "${1:-"  "}" "$2" >&2; }

declare -g NDS_UI_QUIET=false
# Verbose nix install output (nixos-install, partitioning, step exec). The
# session log (events/info/warnings) is NDS_INSTALL_LOG in core/runtime.sh.
declare -g NDS_INSTALL_DETAIL_LOG="/tmp/nds_install.log"

log() {
    if [[ "${NDS_UI_QUIET:-false}" != true ]]; then
        logDate "" "$1"
    fi
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

declare -g NDS_CURRENT_ACTION=""
declare -g NDS_UI_BANNER=""
declare -g NDS_UI_BANNER_WIDTH=100

# Description: Build a section title with optional current action prefix.
nds_section_title_format() {
    local label="$1"
    if [[ "$label" == NDS:* ]]; then
        printf '%s' "$label"
        return 0
    fi
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        printf 'NDS: %s — %s' "$NDS_CURRENT_ACTION" "$label"
    else
        printf 'NDS: %s' "$label"
    fi
}

# Description: Redraw the persistent main title bar when set.
nds_ui_redraw_banner() {
    [[ -n "${NDS_UI_BANNER:-}" ]] || return 0
    nds_ui_draw_box "$NDS_UI_BANNER" "$NDS_UI_BANNER_WIDTH"
}

draw_title() {
    local title="$1"
    local width="${2:-$NDS_UI_BANNER_WIDTH}"
    nds_ui_draw_box "$title" "$width"
}

# Description: Clear the screen and redraw the main title bar if configured.
new_section() {
    printf "\033[2J\033[H" >&2
    nds_ui_redraw_banner
}

# Description: Set the persistent main title (wide box) and show it.
section_title() {
    NDS_UI_BANNER=" === $1 === "
    new_section
}

# Description: Start a screen with the main title and a subsection box below.
section_header() {
    local label="$1"
    local title
    new_section
    title=$(nds_section_title_format "$label")
    nds_ui_draw_box "  ${title}  " "$NDS_UI_BANNER_WIDTH"
}
