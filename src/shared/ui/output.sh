#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Console output and logging
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-08-03
# Description:   console(), log levels, and section headers
# ==================================================================================================

console() { echo "${1:-}" >&2; }
newline() { echo >&2; }

# Description: Timestamped line to stderr (legacy; prefer leveled helpers for UI).
logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "${1:-"  "}" "$2" >&2; }

declare -g NDS_UI_QUIET=false
# NDS_INSTALL_DETAIL_LOG lives in core/runtime.sh next to NDS_INSTALL_LOG.

# Description: Emit a leveled line to the console (no timestamp) and install log (with stamp).
# Arguments:
# - level: <String> info|success|warn|error|fatal|debug|validation
# - msg:   <String> Message body
_nds_ui_emit() {
    local level="$1"
    local msg="$2"
    local plain_tag color_code label

    nds_ui_init
    plain_tag="$(nds_ui_log_tag "$level")"

    if [[ "${NDS_UI_QUIET:-false}" != true ]]; then
        if [[ "$NDS_UI_COLOR" == true ]]; then
            case "$level" in
                success) color_code='32'; label='[OK]' ;;
                info) color_code='36'; label='[INFO]' ;;
                warn) color_code='33'; label='[WARN]' ;;
                error|validation) color_code='31'; label='[FAIL]' ;;
                fatal) color_code='31'; label='[FATAL]' ;;
                debug) color_code='35'; label='[DEBUG]' ;;
                *) color_code='0'; label='[LOG]' ;;
            esac
            if [[ "$NDS_UI_MODE" == "unicode" ]]; then
                printf '  %s %s\n' "$plain_tag" "$msg" >&2
            else
                printf '  \033[%sm%s\033[0m - %s\n' "$color_code" "$label" "$msg" >&2
            fi
        else
            printf '  %s %s\n' "$plain_tag" "$msg" >&2
        fi
    fi

    if declare -f nds_install_log &>/dev/null; then
        nds_install_log "${plain_tag} ${msg}"
    fi
}

log() {
    if [[ "${NDS_UI_QUIET:-false}" != true ]]; then
        printf '  %s\n' "$1" >&2
    fi
    if declare -f nds_install_log &>/dev/null; then
        nds_install_log "$1"
    fi
}

info() { _nds_ui_emit info "$1"; }
error() { _nds_ui_emit error "$1"; }
fatal() { _nds_ui_emit fatal "$1"; }
success() { _nds_ui_emit success "$1"; }
debug() { [[ "${DEBUG:-0}" == "1" ]] && _nds_ui_emit debug "$1" || true; }
warn() { _nds_ui_emit warn "$1"; }
validation_error() { _nds_ui_emit validation "$1"; }

declare -g NDS_UI_BANNER_SUBTITLE=""

# Description: Clear the screen and redraw the persistent NDS banner.
nds_ui_new_section() {
    printf '\033[2J\033[H' >&2
    nds_ui_banner "${NDS_UI_BANNER_SUBTITLE:-}"
}

# Description: Show a screen with the banner and a raw subtitle.
nds_ui_section_title() {
    NDS_UI_BANNER_SUBTITLE="$1"
    nds_ui_new_section
}

# Description: Show a screen with the banner and a subsection subtitle,
# prefixed with the current action name when inside one.
nds_ui_section_header() {
    local label="$1"
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        NDS_UI_BANNER_SUBTITLE="${NDS_CURRENT_ACTION} — ${label}"
    else
        NDS_UI_BANNER_SUBTITLE="$label"
    fi
    nds_ui_new_section
}
