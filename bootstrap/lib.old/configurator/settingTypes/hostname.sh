#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Hostname
# Feature:       Hostname validation (RFC 1123)
# ==================================================================================================

_hostname_promptHint() {
    echo "(alphanumeric, hyphens allowed, no leading/trailing hyphens)"
}

_hostname_validate() {
    local value="$1"
    
    # RFC 1123 hostname rules:
    # - 1-63 characters
    # - alphanumeric and hyphens only
    # - cannot start or end with hyphen
    # - lowercase recommended
    
    if [[ ! "$value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 1
    fi
    
    return 0
}

_hostname_normalize() {
    local value="$1"
    # Convert to lowercase
    echo "${value,,}"
}

_hostname_errorCode() {
    echo "Invalid hostname. Use 1-63 alphanumeric characters and hyphens (no leading/trailing hyphens)"
}

# Auto-register this settingType
nds_cfg_settingType_register "hostname"
