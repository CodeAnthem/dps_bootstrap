#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Float
# Feature:       Floating point number validation
# ==================================================================================================

_float_promptHint() {
    echo "(decimal number)"
}

_float_validate() {
    local value="$1"
    [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

_float_errorCode() {
    echo "Must be a number (integer or decimal)"
}

# Auto-register this settingType
nds_cfg_settingType_register "float"
