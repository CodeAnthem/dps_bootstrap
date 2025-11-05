#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Quick Setup Preset
# Feature:       Quick configuration via country selection
# ==================================================================================================

# Create preset
nds_cfg_preset_create "quick" \
    --display "Quick Setup" \
    --priority 10

# Declare settings
nds_cfg_setting_create COUNTRY \
    --type country \
    --display "Country (quick setup)" \
    --default "" \
    --exportable false

nds_cfg_setting_create HOSTNAME \
    --type hostname \
    --display "System Hostname" \
    --default "nixos"

