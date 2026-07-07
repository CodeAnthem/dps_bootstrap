#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Entry point
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-07-06
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

readonly SCRIPT_VERSION="5.14.0"
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
        _nds_callHook "exit_cleanup" "$exit_code" || true
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

_nds_apply_auto_confirm_flags() {
    export NDS_AUTO_CONFIRM=true
    export NDS_SKIP_MENU=true
    export NDS_ACTION_PREVIEW_SKIP=true
    export NDS_CONFIG_CONFIRM_SKIP=true
    export NDS_INSTALL_CONFIRM_SKIP=true
    export NDS_REMOTE_CONFIRM_SKIP=true
    export NDS_GIT_AUTH_SKIP=true
    export NDS_DISK_FORMAT_CONFIRM_SKIP=true
    export NDS_BACKUP_CONFIRM_SKIP=true
    export NDS_REBOOT_SKIP=true
    export NDS_SCAFFOLD_OVERWRITE_SKIP=true
    export NDS_HARDWARE_OVERWRITE_SKIP=true
    export NDS_PREFLIGHT_WARN_SKIP=true
    export NDS_PROMPTS_SKIP=true
}

declare -a ORIGINAL_ARGS=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-confirm) _nds_apply_auto_confirm_flags; shift ;;
        --skip-menu) export NDS_SKIP_MENU=true; shift ;;
        --action)
            [[ -n "${2:-}" ]] || { echo "Missing value for --action"; exit 1; }
            export NDS_ACTION="$2"
            shift 2
            ;;
        --help|-h)
            cat <<'EOF'
Usage: bootstrap/main.sh [options]

Options:
  --auto-confirm   Skip interactive menus and Y/n prompts (headless install)
  --skip-menu      Skip the configuration category menu when validation passes
  --action NAME    Enter action NAME directly (e.g. installFlake)
  --help           Show this help

Environment (menu skip flags — each also honored when --auto-confirm is set):
  NDS_ACTION                  Action name — skip action picker
  NDS_ACTION_PREVIEW_SKIP     Skip install preview screen
  NDS_SKIP_MENU               Skip configuration category menu
  NDS_CONFIG_CONFIRM_SKIP     Skip "continue to installation review"
  NDS_INSTALL_CONFIRM_SKIP    Skip local install confirmation
  NDS_REMOTE_CONFIRM_SKIP     Skip remote install confirmation
  NDS_GIT_AUTH_SKIP           Skip interactive git SSH auth wizard
  NDS_DISK_FORMAT_CONFIRM_SKIP  Skip destructive disk format confirmation
  NDS_BACKUP_CONFIRM_SKIP     Skip backup zip copy confirmation
  NDS_REBOOT_SKIP             Skip reboot prompt after install
  NDS_SCAFFOLD_OVERWRITE_SKIP Skip scaffold host-dir overwrite prompt
  NDS_HARDWARE_OVERWRITE_SKIP Skip hardware file overwrite prompt
  NDS_PREFLIGHT_WARN_SKIP     Auto-continue past preflight warnings
  NDS_PROMPTS_SKIP            Skip generic Y/n prompts (nds_askUser*)
  NDS_AUTO_CONFIRM            Umbrella — same effect as all skip flags above
EOF
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
