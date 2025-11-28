#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Boot Preset
# Feature:       Bootloader and UEFI configuration for NixOS installation
# ==================================================================================================

# Create preset
nds_cfg_preset_create "boot" \
    --display "Boot" \
    --priority 30

# Declare settings
nds_cfg_setting_create UEFI_MODE \
    --type toggle \
    --display "UEFI Mode" \
    --default "true"

nds_cfg_setting_create BOOTLOADER \
    --type choice \
    --display "Bootloader" \
    --default "systemd-boot" \
    --options "systemd-boot|grub|refind"

