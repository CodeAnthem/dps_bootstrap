#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-27
# Description:   Boot Module - Configuration & NixOS Generation
# Feature:       Bootloader, UEFI, secure boot configuration and NixOS config generation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
boot_init_callback() {
    nds_field_declare UEFI_MODE \
        display="UEFI Mode" \
        input=toggle \
        required=true \
        default=true
    
    nds_field_declare BOOTLOADER \
        display="Bootloader" \
        input=choice \
        required=true \
        default="systemd-boot" \
        options="systemd-boot|grub|refind"
    
    nds_field_declare SECURE_BOOT \
        display="Enable Secure Boot" \
        input=toggle \
        default=false
    
    nds_field_declare SECURE_BOOT_METHOD \
        display="Secure Boot Method" \
        input=choice \
        default="lanzaboote" \
        options="lanzaboote|sbctl"
    
    nds_field_declare BOOT_TIMEOUT \
        display="Boot Menu Timeout (seconds)" \
        input=int \
        default="5" \
        min=0 \
        max=30
    
    nds_field_declare BOOT_ANIMATION \
        display="Boot Animation" \
        input=choice \
        default="normal" \
        options="normal|quiet|verbose"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
boot_get_active_fields() {
    local uefi secure_boot
    uefi=$(nds_config_get "boot" "UEFI_MODE")
    secure_boot=$(nds_config_get "boot" "SECURE_BOOT")
    
    # Base fields
    echo "UEFI_MODE"
    echo "BOOTLOADER"
    echo "BOOT_TIMEOUT"
    echo "BOOT_ANIMATION"
    
    # Secure boot fields only if enabled
    if [[ "$secure_boot" == "true" ]]; then
        echo "SECURE_BOOT"
        echo "SECURE_BOOT_METHOD"
    else
        echo "SECURE_BOOT"
    fi
}

# =============================================================================
# CONFIGURATION - Cross-Field Validation
# =============================================================================
boot_validate_extra() {
    local uefi bootloader secure_boot
    uefi=$(nds_config_get "boot" "UEFI_MODE")
    bootloader=$(nds_config_get "boot" "BOOTLOADER")
    secure_boot=$(nds_config_get "boot" "SECURE_BOOT")
    
    # Validate bootloader compatibility with UEFI/BIOS
    if [[ "$uefi" == "false" ]]; then
        if [[ "$bootloader" == "systemd-boot" || "$bootloader" == "refind" ]]; then
            validation_error "$bootloader requires UEFI mode"
            return 1
        fi
    fi
    
    # Warn about secure boot
    if [[ "$secure_boot" == "true" ]]; then
        if [[ "$uefi" == "false" ]]; then
            validation_error "Secure Boot requires UEFI mode"
            return 1
        fi
        
        warn "Secure Boot requires manual BIOS configuration after install"
        warn "You will need to enroll keys in UEFI firmware"
    fi
    
    return 0
}

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
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
# NIXOS CONFIG GENERATION - Implementation
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
