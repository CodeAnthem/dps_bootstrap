#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# Description:   Shared flake helpers for installFlake + remoteAction actions
# Feature:       Prepare flake env, detect disko strategy, find a flake's action script
# ==================================================================================================

# Description: Export NDS_FLAKE_* env vars from the configurator answers so the
# install pipeline (nds_nixos_install_flake) can read them. Also mirrors the
# chosen host into NETWORK_HOSTNAME. Pass a source ("remote"|"local") to override
# FLAKE_SOURCE — remoteAction always uses "remote".
# Arguments:
# - source: <String|optional> "remote" | "local" (default: read FLAKE_SOURCE)
nds_flake_prepare() {
    local source="${1:-$(nds_configurator_config_get "FLAKE_SOURCE")}"
    [[ -z "$source" || "$source" == "none" ]] && source="remote"

    local host repo_url local_path install_path host_dir hw_placement disk_strategy
    host=$(nds_configurator_config_get "FLAKE_HOST")
    repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")
    local_path=$(nds_configurator_config_get "FLAKE_LOCAL_PATH")
    install_path=$(nds_configurator_config_get "FLAKE_INSTALL_PATH")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    hw_placement=$(nds_configurator_config_get "FLAKE_HARDWARE_PLACEMENT")
    disk_strategy=$(nds_config_get "disk" "DISK_STRATEGY")

    nds_configurator_config_set "NETWORK_HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"
    export NDS_FLAKE_SOURCE="$source"
    export NDS_FLAKE_REPO_URL="$repo_url"
    export NDS_FLAKE_LOCAL_PATH="$local_path"
    export NDS_FLAKE_INSTALL_PATH="$install_path"
    export NDS_FLAKE_HOST_DIR="$host_dir"
    export NDS_HARDWARE_PLACEMENT="$hw_placement"
    export NDS_DISK_STRATEGY="$disk_strategy"

    log "Flake target: ${install_path}#${host} (source: ${source})"
}

# Description: Inspect the flake (local path or remote clone) and apply a disko
# disk strategy if the flake declares one. Best-effort — silently skips when no
# disko config is found or the source is unavailable.
nds_flake_detect_disko() {
    local source host host_dir local_path repo_url probe_root
    source=$(nds_configurator_config_get "FLAKE_SOURCE")
    host=$(nds_configurator_config_get "FLAKE_HOST")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    host_dir="${host_dir:-hosts/x86_64-linux}"

    case "$source" in
        local)
            local_path=$(nds_configurator_config_get "FLAKE_LOCAL_PATH")
            [[ -d "$local_path" ]] && nds_preflight_apply_disko_strategy "$local_path" "$host" "$host_dir"
            ;;
        remote)
            repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")
            [[ -z "$repo_url" ]] && return 0
            probe_root=$(nds_preflight_probe_flake "$repo_url") || return 0
            nds_preflight_apply_disko_strategy "$probe_root" "$host" "$host_dir"
            ;;
    esac
}

# Description: Locate a flake's custom NDS action script, searching standard
# locations. Returns the first match.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# Returns:
# - <String> Path to the action script (stdout), exit 1 if none found
nds_flake_find_action_script() {
    local flake_root="$1"
    local candidate

    for candidate in \
        "${flake_root}/.nds/action.sh" \
        "${flake_root}/nds-action/setup.sh" \
        "${flake_root}/.nds/setup.sh"; do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}
