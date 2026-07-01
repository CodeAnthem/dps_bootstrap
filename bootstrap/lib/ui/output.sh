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
declare -g NDS_UI_BANNER_SUBTITLE=""

# Description: Format a section subtitle. Inside an action, prefix the action
# name for context; otherwise just the label. (No "NDS:" prefix — the banner
# already shows the NDS title line.)
nds_section_title_format() {
    local label="$1"
    if [[ "$label" == NDS:* ]]; then
        printf '%s' "${label#NDS: }"
        return 0
    fi
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        printf '%s — %s' "$NDS_CURRENT_ACTION" "$label"
    else
        printf '%s' "$label"
    fi
}

# Description: Redraw the persistent NDS banner (title + current subtitle).
nds_ui_redraw_banner() {
    nds_ui_banner "${NDS_UI_BANNER_SUBTITLE:-}"
}

draw_title() {
    local title="$1"
    nds_ui_banner "$title"
}

# Description: Clear the screen and redraw the NDS banner.
new_section() {
    printf "\033[2J\033[H" >&2
    nds_ui_redraw_banner
}

# Description: Show the title screen (banner with the given subtitle).
section_title() {
    NDS_UI_BANNER_SUBTITLE="${1#NDS: }"
    new_section
}

# Description: Start a screen with the NDS banner title + this section as subtitle.
section_header() {
    local label="$1"
    NDS_UI_BANNER_SUBTITLE=$(nds_section_title_format "$label")
    new_section
}
