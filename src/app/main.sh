#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - App entry point
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-07-29
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly APP_DIR="${currentPath}"
SCRIPT_DIR="$(cd "${APP_DIR}/.." && pwd || exit 1)"
readonly SCRIPT_DIR

readonly SCRIPT_VERSION="$(< "${APP_DIR}/VERSION")"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper)"

declare -gA NDS_HOOK_FUNCTIONS=(
    ["exit_msg"]="hook_exit_msg"
    ["exit_cleanup"]="hook_exit_cleanup"
)

_app_elevate_to_root() {
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
    local scoped_file="${NDS_SCOPED_CONFIG_FILE:-}"

    # Associative arrays cannot cross sudo — dump to a file when helpers are loaded.
    if [[ -z "$scoped_file" ]] && declare -f nds_cfg_dump_scoped_file &>/dev/null; then
        scoped_file="$(mktemp /tmp/nds-scoped-XXXXXX.env)"
        nds_cfg_dump_scoped_file "$scoped_file" 2>/dev/null || rm -f "$scoped_file"
        [[ -f "$scoped_file" ]] && nds_vars+=("NDS_SCOPED_CONFIG_FILE=$scoped_file")
    elif [[ -n "$scoped_file" ]]; then
        nds_vars+=("NDS_SCOPED_CONFIG_FILE=$scoped_file")
    fi

    while IFS='=' read -r name value; do
        [[ "$name" =~ ^NDS_ ]] || continue
        [[ "$name" == "NDS_SCOPED_CONFIG_FILE" ]] && continue
        nds_vars+=("$name=$value")
    done < <(env)
    if [[ ${#nds_vars[@]} -gt 0 ]]; then
        exec sudo "${nds_vars[@]}" DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "${_app_original_args[@]}"
    fi
    exec sudo DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "${_app_original_args[@]}"
}

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/core/import.sh"

declare -a _app_original_args=("$@")

nds_app_bootstrap() {
    nds_import_file "${SCRIPT_DIR}/app/lifecycle.sh" || return 1
    nds_lifecycle_load_core "$SCRIPT_DIR" || return 1
    nds_lifecycle_load_ui "$SCRIPT_DIR" || return 1
    nds_lifecycle_load_actions "$SCRIPT_DIR" || return 1
    return 0
}

nds_app_run() {
    if [[ "${_NDS_AUTO_CONFIRM_REQUESTED:-false}" == "true" ]]; then
        nds_skip_all
    fi

    trap 'newline; exit 130' SIGINT
    trap _app_stop_handler EXIT

    nds_runtime_init || crash "Failed to setup runtime directory"
    nds_install_log "NDS session started (v$SCRIPT_VERSION)"

    nds_actions_discover "${SCRIPT_DIR}/actions" || crash "Failed to discover actions"
    nds_actions_main || crash "Failed to execute action"
}

main() {
    nds_app_bootstrap || exit 1

    nds_app_parse_args "$@" || {
        local rc=$?
        [[ "$rc" -eq 2 ]] && exit 0
        exit "$rc"
    }

    _app_elevate_to_root
    nds_app_run
}

main "$@"
