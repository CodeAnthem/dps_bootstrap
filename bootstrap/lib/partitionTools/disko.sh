#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2025-11-03
# Description:   Disko-based partitioning workflow (template+params or user file)
# Feature:       Generate params.nix and apply a flexible disko template; or run user-provided file
# ==================================================================================================

# ----------------------------------------------------------------------------------
# PARAM GENERATION (from arguments)
# ----------------------------------------------------------------------------------

_nds_partition_disko_generate_params() {
    local out="$1" disk="$2" fs_type="$3" swap_mib="$4" separate_home="$5" home_size="$6" enc="$7" unlock="$8"
    [[ -n "$out" && -n "$disk" ]] || { error "Missing params"; return 1; }

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

# ----------------------------------------------------------------------------------
# TEMPLATE SELECTION
# ----------------------------------------------------------------------------------
_nds_partition_disko_pick_template() {
    # Single universal template for now
    local this_dir; this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$this_dir/diskoTemplates/default.nix"
}

# ----------------------------------------------------------------------------------
# APPLY DISKO
# ----------------------------------------------------------------------------------
_nds_partition_disko_apply() {
    local disk="$1" fs_type="$2" swap_mib="$3" separate_home="$4" home_size="$5" enc="$6" unlock="$7" user_file="$8"
    local params_path; params_path="$(pwd)/params.nix"

    export NIX_CONFIG="experimental-features = nix-command flakes"

    if [[ -n "$user_file" ]]; then
        warn "Using user-provided disko file: $user_file"
        nix run github:nix-community/disko -- --mode disko "$user_file"
        return $?
    fi

    local tmpl; tmpl=$(_nds_partition_disko_pick_template)
    _nds_partition_disko_generate_params "$params_path" "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock" || return 1

    nix run github:nix-community/disko -- --mode disko "$tmpl"
}
