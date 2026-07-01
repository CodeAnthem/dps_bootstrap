#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2026-06-30
# Description:   Boot Module - Configuration & NixOS Generation
# Feature:       Bootloader and UEFI configuration for NixOS installation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
boot_init() {
    local uefi_default bootloader_default

    if nds_platform_is_uefi; then
        uefi_default=true
        bootloader_default=systemd-boot
    else
        uefi_default=false
        bootloader_default=grub
    fi

    nds_configurator_preset_set_display "boot" "Boot"
    nds_configurator_preset_set_priority "boot" 30

    nds_configurator_var_declare BOOT_UEFI_MODE \
        display="UEFI Mode" \
        input=toggle \
        required=true \
        default="$uefi_default" \
        help="Auto-detected from firmware. systemd-boot needs UEFI; GRUB works on BIOS and UEFI."

    nds_configurator_var_declare BOOT_LOADER \
        display="Bootloader" \
        input=choice \
        required=true \
        default="$bootloader_default" \
        options="systemd-boot|grub|refind" \
        option_labels="systemd-boot=systemd-boot (UEFI only)|grub=GRUB (BIOS + UEFI)|refind=rEFInd (UEFI only)"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
boot_get_active() {
    echo "BOOT_UEFI_MODE"
    echo "BOOT_LOADER"
}

boot_validate_extra() {
    local uefi bootloader

    uefi=$(nds_configurator_config_get "BOOT_UEFI_MODE")
    bootloader=$(nds_configurator_config_get "BOOT_LOADER")

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        validation_error "systemd-boot requires UEFI — pick GRUB or enable UEFI mode"
        return 1
    fi

    if [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        validation_error "rEFInd requires UEFI — pick GRUB or enable UEFI mode"
        return 1
    fi

    if [[ "$uefi" == "true" && ! -d /sys/firmware/efi/efivars ]]; then
        validation_error "UEFI mode is on but the live ISO is BIOS-booted — reboot the ISO in UEFI or disable UEFI mode"
        return 1
    fi

    return 0
}
