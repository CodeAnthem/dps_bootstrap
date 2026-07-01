#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-07-01
# Description:   Disk Module - Configuration
# Feature:       Disk partitioning and swap (encryption lives in the encryption preset)
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
disk_init() {
    nds_configurator_preset_set_display "disk" "Disk"
    nds_configurator_preset_set_priority "disk" 20

    local first_disk=""
    first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)

    nds_configurator_var_declare DISK_TARGET \
        display="Target Disk" \
        input=disk \
        default="$first_disk" \
        required=true

    nds_configurator_var_declare DISK_STRATEGY \
        display="Partitioning method" \
        input=choice \
        default="nds" \
        options="nds|disko|flake" \
        option_labels="nds=NDS built-in (UEFI or BIOS)|disko=Disko template|flake=Your flake (NDS skips disk)" \
        help="How the target disk is prepared. NDS built-in is the default guided layout."

    nds_configurator_var_declare FS_TYPE \
        display="Root filesystem" \
        input=choice \
        default="ext4" \
        options="ext4|btrfs" \
        required=false

    nds_configurator_var_declare SWAP_SIZE_MIB \
        display="Swap size (MiB, 0=none)" \
        input=int \
        default="0" \
        min=0 \
        max=65536 \
        required=false

    nds_configurator_var_declare DISKO_CONFIG \
        display="Disko config file (optional)" \
        input=path \
        default="" \
        required=false \
        help="Path to a .nix disko config (in flake or on live system). Empty = NDS built-in template."
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
disk_get_active() {
    echo "DISK_TARGET"
    echo "DISK_STRATEGY"

    local strategy
    strategy=$(nds_configurator_config_get "DISK_STRATEGY")
    if [[ "$strategy" == "disko" ]]; then
        echo "FS_TYPE"
        echo "SWAP_SIZE_MIB"
        echo "DISKO_CONFIG"
    fi
}
