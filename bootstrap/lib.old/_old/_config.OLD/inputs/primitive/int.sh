#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Integer
# Feature:       Integer number validation with optional min/max range
# ==================================================================================================

# ----------------------------------------------------------------------------------
# INT INPUT
# ----------------------------------------------------------------------------------

prompt_hint_int() {
    local min max
    min=$(_nds_configurator_get_validator_opt "min" "")
    max=$(_nds_configurator_get_validator_opt "max" "")
    
    if [[ -n "$min" && -n "$max" ]]; then
        echo "($min-$max)"
    elif [[ -n "$min" ]]; then
        echo "(min: $min)"
    elif [[ -n "$max" ]]; then
        echo "(max: $max)"
    fi
}

validate_int() {
    local value="$1"
    local min max
    min=$(_nds_configurator_get_validator_opt "min" "")
    max=$(_nds_configurator_get_validator_opt "max" "")
    
    # Must be integer
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
    
    # Check range if specified
    [[ -n "$min" && "$value" -lt "$min" ]] && return 2
    [[ -n "$max" && "$value" -gt "$max" ]] && return 2
    
    return 0
}

error_msg_int() {
    local value="$1"
    local code="${2:-0}"
    local min max
    min=$(_nds_configurator_get_validator_opt "min" "")
    max=$(_nds_configurator_get_validator_opt "max" "")
    
    case "$code" in
        1)
            echo "Must be an integer (no letters or special characters)"
            ;;
        2)
            if [[ -n "$min" && -n "$max" ]]; then
                echo "Must be between $min and $max"
            elif [[ -n "$min" ]]; then
                echo "Must be >= $min"
            elif [[ -n "$max" ]]; then
                echo "Must be <= $max"
            else
                echo "Out of range"
            fi
            ;;
        *)
            echo "Must be an integer"
            ;;
    esac
}
