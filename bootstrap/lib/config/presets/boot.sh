#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-28
# Description:   Boot Module - Configuration & NixOS Generation
# Feature:       Bootloader and UEFI configuration for NixOS installation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
boot_init() {
    nds_configurator_var_declare UEFI_MODE \
        display="UEFI Mode" \
        input=toggle \
        required=true \
        default=true
    
    nds_configurator_var_declare BOOTLOADER \
        display="Bootloader" \
        input=choice \
        required=true \
        default="systemd-boot" \
        options="systemd-boot|grub|refind"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
boot_get_active() {
    # UEFI_MODE must come first as BOOTLOADER selection may depend on it
    echo "UEFI_MODE"
    echo "BOOTLOADER"
}

# Note: No cross-field validation needed for boot module

