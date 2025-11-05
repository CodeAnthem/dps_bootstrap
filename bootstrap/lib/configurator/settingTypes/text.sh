#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   SettingType - Text
# Feature:       Simple text input with no restrictions
# ==================================================================================================

_text_promptHint() { 
    echo "(text input)"
}

_text_validate() {
    local value="$1"
    # Text input is always valid (even empty)
    return 0
}

_text_normalize() {
    local value="$1"
    # No normalization needed
    echo "$value"
}

_text_errorCode() {
    local value="$1"
    # Text input doesn't have errors
    echo ""
}

# Auto-register this settingType
nds_cfg_settingType_register "text"
