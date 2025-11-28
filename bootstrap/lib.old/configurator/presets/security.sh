#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Security Preset
# Feature:       Secure boot, firewall, hardening, and security configuration
# ==================================================================================================

# Create preset
nds_cfg_preset_create "security" \
    --display "Security" \
    --priority 40

# Base settings
nds_cfg_setting_create SECURE_BOOT \
    --type toggle \
    --display "Enable Secure Boot" \
    --default "false"

nds_cfg_setting_create SECURE_BOOT_METHOD \
    --type choice \
    --display "Secure Boot Method" \
    --default "lanzaboote" \
    --options "lanzaboote|sbctl" \
    --visible_all "SECURE_BOOT==true"

nds_cfg_setting_create FIREWALL_ENABLE \
    --type toggle \
    --display "Enable Firewall" \
    --default "true"

nds_cfg_setting_create HARDENING_ENABLE \
    --type toggle \
    --display "Apply Security Hardening" \
    --default "true"

nds_cfg_setting_create FAIL2BAN_ENABLE \
    --type toggle \
    --display "Enable Fail2Ban" \
    --default "false"

