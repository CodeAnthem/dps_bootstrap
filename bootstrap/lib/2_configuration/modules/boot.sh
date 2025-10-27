#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   Configuration Module - Boot Settings
# Feature:       Bootloader, UEFI, and secure boot configuration
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
boot_init_callback() {
    field_declare UEFI_MODE \
        display="UEFI Mode" \
        input=toggle \
        required=true \
        default=true
    
    field_declare BOOTLOADER \
        display="Bootloader" \
        input=choice \
        required=true \
        default="systemd-boot" \
        options="systemd-boot|grub|refind"
    
    field_declare SECURE_BOOT \
        display="Enable Secure Boot" \
        input=toggle \
        default=false
    
    field_declare SECURE_BOOT_METHOD \
        display="Secure Boot Method" \
        input=choice \
        default="lanzaboote" \
        options="lanzaboote|sbctl"
    
    field_declare BOOT_TIMEOUT \
        display="Boot Menu Timeout (seconds)" \
        input=int \
        default="5" \
        min=0 \
        max=30
    
    field_declare BOOT_ANIMATION \
        display="Boot Animation" \
        input=choice \
        default="normal" \
        options="normal|quiet|verbose"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
boot_get_active_fields() {
    local uefi secure_boot
    uefi=$(config_get "boot" "UEFI_MODE")
    secure_boot=$(config_get "boot" "SECURE_BOOT")
    
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
# CROSS-FIELD VALIDATION
# =============================================================================
boot_validate_extra() {
    local uefi bootloader secure_boot
    uefi=$(config_get "boot" "UEFI_MODE")
    bootloader=$(config_get "boot" "BOOTLOADER")
    secure_boot=$(config_get "boot" "SECURE_BOOT")
    
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
