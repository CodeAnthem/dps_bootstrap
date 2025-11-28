#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - String
# Feature:       Alphanumeric string validation with optional length constraints
# ==================================================================================================

# ----------------------------------------------------------------------------------
# STRING INPUT
# ----------------------------------------------------------------------------------

prompt_hint_string() {
    local minlen maxlen
    minlen=$(_nds_configurator_get_validator_opt "minlen" "")
    maxlen=$(_nds_configurator_get_validator_opt "maxlen" "")
    
    if [[ -n "$minlen" && -n "$maxlen" ]]; then
        echo "(length: $minlen-$maxlen chars)"
    elif [[ -n "$minlen" ]]; then
        echo "(min: $minlen chars)"
    elif [[ -n "$maxlen" ]]; then
        echo "(max: $maxlen chars)"
    fi
}

validate_string() {
    local value="$1"
    local minlen maxlen pattern
    minlen=$(_nds_configurator_get_validator_opt "minlen" "")
    maxlen=$(_nds_configurator_get_validator_opt "maxlen" "")
    pattern=$(_nds_configurator_get_validator_opt "pattern" "")
    
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

error_msg_string() {
    local value="$1"
    local code="${2:-0}"
    local minlen maxlen pattern
    minlen=$(_nds_configurator_get_validator_opt "minlen" "")
    maxlen=$(_nds_configurator_get_validator_opt "maxlen" "")
    pattern=$(_nds_configurator_get_validator_opt "pattern" "")
    
    case "$code" in
        1)
            if [[ -n "$pattern" ]]; then
                echo "Must match pattern: $pattern"
            else
                echo "Invalid format"
            fi
            ;;
        2)
            if [[ -n "$minlen" && -n "$maxlen" ]]; then
                echo "Length must be between $minlen and $maxlen characters"
            elif [[ -n "$minlen" ]]; then
                echo "Must be at least $minlen characters"
            elif [[ -n "$maxlen" ]]; then
                echo "Must be at most $maxlen characters"
            else
                echo "Length out of range"
            fi
            ;;
        *)
            echo "Invalid string"
            ;;
    esac
}
