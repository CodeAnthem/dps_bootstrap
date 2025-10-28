#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   NixOS Config Generation - Boot Module
# Feature:       Bootloader configuration (systemd-boot, GRUB, rEFInd)
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_boot_auto() {
    local bootloader uefi
    bootloader=$(nds_config_get "boot" "BOOTLOADER")
    uefi=$(nds_config_get "boot" "UEFI_MODE")
    
    _nixcfg_boot_generate "$bootloader" "$uefi"
}

# Manual mode: explicit parameters
nds_nixcfg_boot() {
    local bootloader="$1"
    local uefi="${2:-true}"
    
    _nixcfg_boot_generate "$bootloader" "$uefi"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_boot_generate() {
    local bootloader="$1"
    local uefi="$2"
    
    case "$bootloader" in
        systemd-boot)
            _nixcfg_boot_systemd "$uefi"
            ;;
        grub)
            _nixcfg_boot_grub "$uefi"
            ;;
        refind)
            _nixcfg_boot_refind "$uefi"
            ;;
        *)
            error "Unknown bootloader: $bootloader"
            return 1
            ;;
    esac
}

_nixcfg_boot_systemd() {
    local uefi="$1"
    
    local block
    block=$(cat <<EOF
boot.loader = {
  systemd-boot.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)
    
    nds_nixcfg_register "boot" "$block" 10
}

_nixcfg_boot_grub() {
    local uefi="$1"
    
    local block
    if [[ "$uefi" == "true" ]]; then
        block=$(cat <<EOF
boot.loader = {
  grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = false;
  };
  efi.canTouchEfiVariables = true;
};
EOF
)
    else
        block=$(cat <<EOF
boot.loader.grub = {
  enable = true;
  device = "/dev/sda";  # Adjust to your disk
};
EOF
)
    fi
    
    nds_nixcfg_register "boot" "$block" 10
}

_nixcfg_boot_refind() {
    local uefi="$1"
    
    local block
    block=$(cat <<EOF
boot.loader = {
  refind.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)
    
    nds_nixcfg_register "boot" "$block" 10
}
