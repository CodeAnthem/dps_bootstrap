#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Region Preset
# Feature:       Timezone, locale, and keyboard configuration with optional country-based defaults
# ==================================================================================================

# Create preset
nds_cfg_preset_create "region" \
    --display "Region" \
    --priority 50

# Declare settings
nds_cfg_setting_create TIMEZONE \
    --type timezone \
    --display "Timezone" \
    --default "UTC"

nds_cfg_setting_create LOCALE \
    --type locale \
    --display "Primary Locale" \
    --default "en_US.UTF-8"

nds_cfg_setting_create LOCALE_EXTRA \
    --type text \
    --display "Additional Locales" \
    --default ""

nds_cfg_setting_create KEYBOARD_LAYOUT \
    --type keyboard \
    --display "Keyboard Layout" \
    --default "us"

nds_cfg_setting_create KEYBOARD_VARIANT \
    --type keyboardVariant \
    --display "Keyboard Variant (optional)" \
    --default ""

