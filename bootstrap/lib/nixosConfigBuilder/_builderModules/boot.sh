#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   NixOS Config Builder Module - Boot
# Feature:       Generate bootloader configuration blocks
# ==================================================================================================

# =============================================================================
# PUBLIC API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_boot_auto() {
    local bootloader uefi secure_boot timeout
    bootloader=$(nds_config_get "boot" "BOOTLOADER")
    uefi=$(nds_config_get "boot" "UEFI_MODE")
    secure_boot=$(nds_config_get "boot" "SECURE_BOOT")
    timeout=$(nds_config_get "boot" "BOOT_TIMEOUT")
    
    local block
    block=$(_nixcfg_boot_generate "$bootloader" "$uefi" "$secure_boot" "$timeout")
    nds_nixcfg_register "boot" "$block" 10
}

# Manual mode: explicit parameters
nds_nixcfg_boot() {
    local bootloader="$1"
    local uefi="${2:-true}"
    local secure_boot="${3:-false}"
    local timeout="${4:-5}"
    
    local block
    block=$(_nixcfg_boot_generate "$bootloader" "$uefi" "$secure_boot" "$timeout")
    nds_nixcfg_register "boot" "$block" 10
}

# =============================================================================
# PRIVATE - Implementation Functions
# =============================================================================

_nixcfg_boot_generate() {
    local bootloader="$1"
    local uefi="$2"
    local secure_boot="$3"
    local timeout="$4"
    
    case "$bootloader" in
        systemd-boot)
            _nixcfg_boot_systemd "$uefi" "$secure_boot" "$timeout"
            ;;
        grub)
            _nixcfg_boot_grub "$uefi" "$secure_boot" "$timeout"
            ;;
        refind)
            _nixcfg_boot_refind "$uefi" "$timeout"
            ;;
        *)
            error "Unknown bootloader: $bootloader"
            return 1
            ;;
    esac
}

_nixcfg_boot_systemd() {
    local uefi="$1"
    local secure_boot="$2"
    local timeout="$3"
    
    cat <<EOF
boot.loader = {
  systemd-boot.enable = true;
  efi.canTouchEfiVariables = true;
  timeout = $timeout;
$(if [[ "$secure_boot" == "true" ]]; then
    echo "  # Secure Boot via lanzaboote"
    echo "  # See: https://github.com/nix-community/lanzaboote"
fi)
};
EOF
}

_nixcfg_boot_grub() {
    local uefi="$1"
    local secure_boot="$2"
    local timeout="$3"
    
    if [[ "$uefi" == "true" ]]; then
        cat <<EOF
boot.loader = {
  grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = false;
  };
  efi.canTouchEfiVariables = true;
  timeout = $timeout;
};
EOF
    else
        cat <<EOF
boot.loader.grub = {
  enable = true;
  device = "/dev/sda";  # Adjust to your disk
  timeout = $timeout;
};
EOF
    fi
}

_nixcfg_boot_refind() {
    local uefi="$1"
    local timeout="$3"
    
    cat <<EOF
boot.loader = {
  refind.enable = true;
  efi.canTouchEfiVariables = true;
  timeout = $timeout;
};
EOF
}
