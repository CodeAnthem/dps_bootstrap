#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Choice
# Feature:       Selection from predefined options
# ==================================================================================================

_choice_promptHint() {
    # Get options from setting attribute
    local options="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::options"]:-}"
    if [[ -n "$options" ]]; then
        echo "(${options//|/, })"
    else
        echo "(multiple choice)"
    fi
}

_choice_validate() {
    local value="$1"
    
    # Get options from setting attribute
    local options="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::options"]:-}"
    
    if [[ -z "$options" ]]; then
        error "Choice type requires --options attribute"
        return 1
    fi
    
    # Check if value is in options
    local IFS='|'
    for option in $options; do
        if [[ "$value" == "$option" ]]; then
            return 0
        fi
    done
    
    return 1
}

_choice_errorCode() {
    local value="$1"
    local options="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::options"]:-}"
    echo "Must be one of: ${options//|/, }"
}

# Auto-register this settingType
nds_cfg_settingType_register "choice"
