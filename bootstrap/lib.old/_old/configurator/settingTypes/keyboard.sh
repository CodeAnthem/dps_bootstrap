#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   SettingType - Keyboard
# Feature:       Keyboard layout validation
# ==================================================================================================

_keyboard_promptHint() {
    echo "(e.g., us, de, fr, uk, ch)"
}

_keyboard_validate() {
    local value="$1"
    
    # Basic keyboard layout format: 2-3 lowercase letters
    [[ "$value" =~ ^[a-z]{2,5}$ ]]
}

_keyboard_normalize() {
    local value="$1"
    # Convert to lowercase
    echo "${value,,}"
}

_keyboard_errorCode() {
    echo "Invalid keyboard layout. Use 2-5 lowercase letters (e.g., us, de, fr)"
}

# Auto-register this settingType
nds_cfg_settingType_register "keyboard"
