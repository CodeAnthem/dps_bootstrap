#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   SettingType - Timezone
# Feature:       Timezone validation (IANA format)
# ==================================================================================================

_timezone_promptHint() {
    echo "(e.g., America/New_York, Europe/Berlin, UTC)"
}

_timezone_validate() {
    local value="$1"
    
    # Basic IANA timezone format: Region/City or UTC
    if [[ "$value" == "UTC" ]]; then
        return 0
    fi
    
    # Check format: Region/City or Region/Location/City
    if [[ ! "$value" =~ ^[A-Z][a-zA-Z_]+/[A-Z][a-zA-Z_]+(/[A-Z][a-zA-Z_]+)?$ ]]; then
        return 1
    fi
    
    return 0
}

_timezone_errorCode() {
    echo "Invalid timezone. Use IANA format (e.g., America/New_York, Europe/Berlin, UTC)"
}

# Auto-register this settingType
nds_cfg_settingType_register "timezone"
