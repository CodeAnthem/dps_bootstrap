#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2025-11-03
# Description:   Disko-based partitioning workflow (template+params or user file)
# Feature:       Generate params.nix and apply a flexible disko template; or run user-provided file
# ==================================================================================================

# =============================================================================
# PARAM GENERATION
# =============================================================================

nds_partition_disko_generate_params() {
    local out="$1"; [[ -n "$out" ]] || { error "Missing params path"; return 1; }

    local disk fs_type swap_mib separate_home home_size enc unlock keyfile passphrase
    disk=$(nds_configurator_config_get_env "DISK_TARGET") || return 1
    fs_type=$(nds_configurator_config_get_env "FS_TYPE" "btrfs")
    swap_mib=$(nds_configurator_config_get_env "SWAP_SIZE_MIB" "0")
    separate_home=$(nds_configurator_config_get_env "SEPARATE_HOME" "false")
    home_size=$(nds_configurator_config_get_env "HOME_SIZE" "20G")
    enc=$(nds_configurator_config_get_env "ENCRYPTION" "true")
    unlock=$(nds_configurator_config_get_env "ENCRYPTION_UNLOCK_MODE" "manual")

    cat >"$out" <<EOF
{
  disk = "${disk}";
  fsType = "${fs_type}";
  encrypt = ${enc};
  unlockMode = "${unlock}";
  swapSize = ${swap_mib};
  separateHome = ${separate_home};
  homeSize = "${home_size}";
}
EOF
}

# =============================================================================
# TEMPLATE SELECTION
# =============================================================================
_nds_partition_disko_pick_template() {
    # Single universal template for now
    local this_dir; this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$this_dir/diskoTemplates/default.nix"
}

# =============================================================================
# APPLY DISKO
# =============================================================================
nds_partition_disko_apply() {
    local user_file; user_file=$(nds_configurator_config_get_env "DISKO_USER_FILE" "")
    local params_path; params_path="$(pwd)/params.nix"

    export NIX_CONFIG="experimental-features = nix-command flakes"

    if [[ -n "$user_file" ]]; then
        warn "Using user-provided disko file: $user_file"
        nds_askUserToProceed "Apply user disko file to target disk? This is destructive." || return 1
        nix run github:nix-community/disko -- --mode disko "$user_file"
        return $?
    fi

    local tmpl; tmpl=$(_nds_partition_disko_pick_template)
    nds_partition_disko_generate_params "$params_path" || return 1

    nds_askUserToProceed "Apply disko template to target disk? This is destructive." || return 1
    nix run github:nix-community/disko -- --mode disko "$tmpl"
}
