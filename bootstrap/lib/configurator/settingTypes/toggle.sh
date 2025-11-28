#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Toggle
# Feature:       Boolean toggle (true/false, enabled/disabled)
# ==================================================================================================

_toggle_promptHint() {
    echo "(true/false, enabled/disabled)"
}

_toggle_validate() {
    local value="$1"
    [[ "${value,,}" =~ ^(true|false|enabled|disabled|1|0)$ ]]
}

_toggle_normalize() {
    local value="$1"
    case "${value,,}" in
        true|enabled|1) echo "true" ;;
        false|disabled|0) echo "false" ;;
    esac
}

_toggle_display() {
    local value="$1"
    case "$value" in
        true) echo "✓" ;;
        false) echo "✗" ;;
        *) echo "$value" ;;
    esac
}

_toggle_errorCode() {
    echo "Enter true, false, enabled, or disabled"
}

# Auto-register this settingType
nds_cfg_settingType_register "toggle"
