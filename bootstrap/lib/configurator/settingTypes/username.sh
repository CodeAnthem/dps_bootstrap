#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Username
# Feature:       Linux username validation
# ==================================================================================================

_username_promptHint() {
    echo "(2-32 chars, lowercase, start with letter or underscore)"
}

_username_validate() {
    local username="$1"
    
    # Minimum 2 characters for system administration
    [[ ${#username} -ge 2 ]] || return 1
    
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{1,31}$ ]]
}

_username_errorCode() {
    echo "Invalid username (2-32 chars, start with lowercase letter or underscore)"
}

# Auto-register this settingType
nds_cfg_settingType_register "username"
