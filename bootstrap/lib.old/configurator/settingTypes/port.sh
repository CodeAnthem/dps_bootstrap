#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Port Number
# Feature:       Port number validation with configurable min/max range
# ==================================================================================================

_port_promptHint() {
    local min="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::min"]:-1}"
    local max="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::max"]:-65535}"
    echo "($min-$max)"
}

_port_validate() {
    local value="$1"
    local min="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::min"]:-1}"
    local max="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::max"]:-65535}"
    
    # Must be numeric
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    
    # Check range
    (( value >= min && value <= max )) || return 2
    
    return 0
}

_port_errorCode() {
    local value="$1"
    local min="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::min"]:-1}"
    local max="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::max"]:-65535}"
    
    # Check error type by re-validating
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        echo "Port must be numeric (no letters or special characters)"
    else
        echo "Port must be between $min and $max"
    fi
}

# Auto-register this settingType
nds_cfg_settingType_register "port"
