#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Console output and logging
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-06-30
# Description:   console(), log levels, and section headers
# ==================================================================================================

console() { echo "${1:-}" >&2; }
newline() { echo >&2; }

logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "${1:-"  "}" "$2" >&2; }

declare -g NDS_UI_QUIET=false
# NDS_INSTALL_DETAIL_LOG lives in core/runtime.sh next to NDS_INSTALL_LOG.

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

# Description: Clear the screen and redraw the persistent NDS banner.
new_section() {
    printf "\033[2J\033[H" >&2
    nds_ui_banner "${NDS_UI_BANNER_SUBTITLE:-}"
}

# Description: Show a screen with the banner and a raw subtitle.
section_title() {
    NDS_UI_BANNER_SUBTITLE="$1"
    new_section
}

# Description: Show a screen with the banner and a subsection subtitle,
# prefixed with the current action name when inside one.
section_header() {
    local label="$1"
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        NDS_UI_BANNER_SUBTITLE="${NDS_CURRENT_ACTION} — ${label}"
    else
        NDS_UI_BANNER_SUBTITLE="$label"
    fi
    new_section
}
