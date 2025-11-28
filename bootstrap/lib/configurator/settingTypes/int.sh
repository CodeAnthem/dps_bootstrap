#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Integer
# Feature:       Integer validation with optional min/max range
# ==================================================================================================

_int_promptHint() {
    local min="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::min"]:-}"
    local max="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::max"]:-}"
    
    if [[ -n "$min" && -n "$max" ]]; then
        echo "($min-$max)"
    elif [[ -n "$min" ]]; then
        echo "(min: $min)"
    elif [[ -n "$max" ]]; then
        echo "(max: $max)"
    fi
}

_int_validate() {
    local value="$1"
    local min="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::min"]:-}"
    local max="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::max"]:-}"
    
    # Must be integer
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
    
    # Check range if specified
    [[ -n "$min" && "$value" -lt "$min" ]] && return 2
    [[ -n "$max" && "$value" -gt "$max" ]] && return 2
    
    return 0
}

_int_errorCode() {
    local value="$1"
    local min="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::min"]:-}"
    local max="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::max"]:-}"
    
    # Check error type by re-validating
    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        echo "Must be an integer (no letters or special characters)"
    else
        if [[ -n "$min" && -n "$max" ]]; then
            echo "Must be between $min and $max"
        elif [[ -n "$min" ]]; then
            echo "Must be >= $min"
        elif [[ -n "$max" ]]; then
            echo "Must be <= $max"
        else
            echo "Out of range"
        fi
    fi
}

# Auto-register this settingType
nds_cfg_settingType_register "int"
