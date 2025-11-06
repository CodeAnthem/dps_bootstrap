#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - String
# Feature:       String validation with optional length constraints and pattern
# ==================================================================================================

_string_promptHint() {
    local minlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::minlen"]:-}"
    local maxlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::maxlen"]:-}"
    
    if [[ -n "$minlen" && -n "$maxlen" ]]; then
        echo "(length: $minlen-$maxlen chars)"
    elif [[ -n "$minlen" ]]; then
        echo "(min: $minlen chars)"
    elif [[ -n "$maxlen" ]]; then
        echo "(max: $maxlen chars)"
    fi
}

_string_validate() {
    local value="$1"
    local minlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::minlen"]:-}"
    local maxlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::maxlen"]:-}"
    local pattern="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::pattern"]:-}"
    
    # Check pattern if specified
    if [[ -n "$pattern" ]]; then
        [[ "$value" =~ $pattern ]] || return 1
    fi
    
    # Check length if specified
    local len=${#value}
    [[ -n "$minlen" && "$len" -lt "$minlen" ]] && return 2
    [[ -n "$maxlen" && "$len" -gt "$maxlen" ]] && return 2
    
    return 0
}

_string_errorCode() {
    local value="$1"
    local minlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::minlen"]:-}"
    local maxlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::maxlen"]:-}"
    local pattern="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::pattern"]:-}"
    
    # Check error type by re-validating
    if [[ -n "$pattern" && ! "$value" =~ $pattern ]]; then
        echo "Must match pattern: $pattern"
    else
        if [[ -n "$minlen" && -n "$maxlen" ]]; then
            echo "Length must be between $minlen and $maxlen characters"
        elif [[ -n "$minlen" ]]; then
            echo "Must be at least $minlen characters"
        elif [[ -n "$maxlen" ]]; then
            echo "Must be at most $maxlen characters"
        else
            echo "Invalid string"
        fi
    fi
}

# Auto-register this settingType
nds_cfg_settingType_register "string"
