#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Entry point
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-07-06
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

readonly SCRIPT_VERSION="5.8.0"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper)"

currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"
readonly LIB_DIR="${SCRIPT_DIR}/lib"

declare -gA NDS_HOOK_FUNCTIONS=(
    ["exit_msg"]="hook_exit_msg"
    ["exit_cleanup"]="hook_exit_cleanup"
)

# shellcheck disable=SC1091
source "${LIB_DIR}/core/import.sh"

_nds_callHook() {
    local hookName="$1"
    shift
    local hookFunction="${NDS_HOOK_FUNCTIONS[$hookName]}"
    [[ -n "$hookFunction" ]] || { error "Hook '$hookName' not found"; return 1; }
    declare -f "$hookFunction" &>/dev/null && { "$hookFunction" "$@"; return 0; }
    return 1
}

_nds_elevate_to_root() {
    [[ $EUID -eq 0 ]] && return 0
    if ! command -v sudo &>/dev/null; then
        printf '[ERROR] - NDS must run as root, but sudo is not available.\n' >&2
        exit 1
    fi
    if sudo -n true 2>/dev/null; then
        printf '[INFO] - NDS requires root — re-running as root (sudo is passwordless).\n' >&2
    else
        printf '[INFO] - NDS requires root — re-running via sudo.\n' >&2
    fi
    local nds_vars=()
    while IFS='=' read -r name value; do
        [[ "$name" =~ ^NDS_ ]] && nds_vars+=("$name=$value")
    done < <(env)
    if [[ ${#nds_vars[@]} -gt 0 ]]; then
        exec sudo "${nds_vars[@]}" DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "${ORIGINAL_ARGS[@]}"
    fi
    exec sudo DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "${ORIGINAL_ARGS[@]}"
}

setupRuntimeDir() { nds_runtime_init; }
purgeRuntimeDir() { nds_runtime_purge; }

declare -g fatal_message=""
crash() { fatal_message="$1"; exit 200; }

_main_stopHandler() {
    local exit_code=$?
    local exit_msg=""
    exit_msg=$(_nds_callHook "exit_msg" "$exit_code" || true)

    [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]] && return 0

    if [[ -n "$exit_msg" ]]; then
        console "$exit_msg"
    else
        case "${exit_code}" in
            0) success "Script completed successfully" ;;
            130) warn "Script aborted by user" ;;
            200) fatal "Internal error! - ${fatal_message:-}" ;;
            *) warn "Script failed with exit code: $exit_code" ;;
        esac
    fi

    [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]] && return 0

    if [[ "$exit_code" -ne 0 ]]; then
        nds_ui_init
        if [[ "$NDS_UI_COLOR" == true ]]; then
            printf '%s\033[31;1mInstallation failed (exit code %s).\033[0m\n' "$NDS_UI_INDENT_B" "$exit_code" >&2
        else
            printf '%sInstallation failed (exit code %s).\n' "$NDS_UI_INDENT_B" "$exit_code" >&2
        fi
        nds_ui_b ""
        local log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
        if [[ -f "$log" ]]; then
            nds_ui_i "Full log: ${log}"
            nds_ui_b "Last lines:"
            while IFS= read -r _line; do
                printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
            done < <(tail -n 12 "$log" 2>/dev/null)
            nds_ui_b ""
        fi
        return 0
    fi

    info "Cleaning up session"
    purgeRuntimeDir
    _nds_callHook "exit_cleanup" "$exit_code" || true
}

declare -a ORIGINAL_ARGS=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-confirm) export NDS_AUTO_CONFIRM=true NDS_SKIP_MENU=true; shift ;;
        --skip-menu) export NDS_SKIP_MENU=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--auto-confirm] [--skip-menu] [--help]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

nds_import_file "${LIB_DIR}/core/import.sh" || exit 1
_nds_elevate_to_root
nds_bootstrap_load_libs "$SCRIPT_DIR" || exit 1

trap 'newline; exit 130' SIGINT
trap _main_stopHandler EXIT

declare -g RUNTIME_DIR
setupRuntimeDir || crash "Failed to setup runtime directory"
nds_install_log "NDS session started (v$SCRIPT_VERSION)"

nds_actions_discover "${SCRIPT_DIR}/../actions" || crash "Failed to discover actions"
nds_actions_main || crash "Failed to execute action"

exit 0
