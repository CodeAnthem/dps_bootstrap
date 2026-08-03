#!/usr/bin/env bash
# ==================================================================================================
# NDS - System variables (NDS_* env bridge)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-31
# Description:   Map process env NDS_* into settings store; sync derived flake keys
# ==================================================================================================

# Description: Sync FLAKE_LOCATION / FLAKE_SOURCE from FLAKE_REPO_URL or FLAKE_LOCAL_PATH.
nds_cfg_sync_derived_flake() {
    local loc repo local_path src
    loc="$(nds_cfg_get FLAKE_LOCATION)"
    repo="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"

    if [[ -n "$loc" && -z "$repo" && -z "$local_path" ]]; then
        src=$(nds_detect_flake_source "$loc")
        nds_cfg_set FLAKE_SOURCE "$src"
        if [[ "$src" == remote ]]; then
            nds_cfg_set FLAKE_REPO_URL "$loc"
            nds_cfg_set FLAKE_LOCAL_PATH ""
        else
            nds_cfg_set FLAKE_LOCAL_PATH "$loc"
            nds_cfg_set FLAKE_REPO_URL ""
        fi
        return 0
    fi

    if [[ -n "$repo" ]]; then
        nds_cfg_set FLAKE_LOCATION "$repo"
        nds_cfg_set FLAKE_SOURCE "remote"
        nds_cfg_set FLAKE_LOCAL_PATH ""
    elif [[ -n "$local_path" ]]; then
        nds_cfg_set FLAKE_LOCATION "$local_path"
        nds_cfg_set FLAKE_SOURCE "local"
        nds_cfg_set FLAKE_REPO_URL ""
    fi
}

# Description: Apply every NDS_* environment variable to CONFIG_DATA, then sync derived keys.
# Also loads NDS_SCOPED_CONFIG_FILE (declare -A blocks) — AAs cannot cross sudo without a file.
nds_cfg_apply_env_all() {
    local env_name key
    local loaded_scoped=false

    if [[ -n "${NDS_SCOPED_CONFIG_FILE:-}" && -f "${NDS_SCOPED_CONFIG_FILE}" ]]; then
        if declare -f nds_cfg_load_scoped_file &>/dev/null; then
            nds_cfg_load_scoped_file
            loaded_scoped=true
        fi
    fi

    while IFS= read -r env_name; do
        [[ "$env_name" == NDS_* ]] || continue
        case "$env_name" in
            NDS_SCOPED_CONFIG_FILE|NDS_RUNTIME_DIR|NDS_INSTALL_LOG|NDS_INSTALL_DETAIL_LOG|NDS_INSTALL_DIAG_LOG|\
            NDS_GIT_GH_BIN|NDS_GIT_GH_PREFETCH_DONE|NDS_GIT_GH_PREFETCH_IN_PROGRESS|NDS_GIT_ACCESS_VERIFIED|\
            NDS_FLAKE_PROBE_REPO|NDS_FLAKE_PROBE_REPO_URL|NDS_GIT_GH_LEFTOVER|NDS_GIT_GH_SESSION_ACTIVE|\
            NDS_GIT_GH_HAS_KEY_SCOPE|NDS_GIT_INSTALL_SUCCEEDED|NDS_GIT_CLOSURE_URLS)
                continue
                ;;
        esac
        key="${env_name#NDS_}"
        [[ -n "${!env_name:-}" ]] || continue
        case "$key" in
            FLAKE|DISK|BOOT|ENCRYPTION|NETWORK|PLATFORM|ACCESS|REGION|SECURITY|QUICK|GIT_METHOD|GIT_KEY_PATH|GIT_KEY_KIND)
                continue
                ;;
        esac
        CONFIG_DATA["$key"]="${!env_name}"
        debug "Env: ${env_name}=${!env_name}"
    done < <(compgen -e | grep '^NDS_' || true)

    nds_cfg_sync_derived_flake
    if declare -f nds_cfg_sync_store_to_scoped &>/dev/null; then
        nds_cfg_sync_store_to_scoped
    fi
}

nds_config_apply_env() {
    nds_cfg_apply_env_all
}
