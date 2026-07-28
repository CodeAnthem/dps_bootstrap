#!/usr/bin/env bash
# ==================================================================================================
# NDS - System variables (NDS_* env bridge)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
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
nds_cfg_apply_env_all() {
    local env_name key
    while IFS= read -r env_name; do
        [[ "$env_name" == NDS_* ]] || continue
        key="${env_name#NDS_}"
        [[ -n "${!env_name:-}" ]] || continue
        CONFIG_DATA["$key"]="${!env_name}"
        debug "Env: ${env_name}=${!env_name}"
    done < <(compgen -e | grep '^NDS_' || true)
    nds_cfg_sync_derived_flake
}

nds_config_apply_env() {
    nds_cfg_apply_env_all
}
