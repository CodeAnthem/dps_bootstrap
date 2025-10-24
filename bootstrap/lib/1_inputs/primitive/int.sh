#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Integer
# Feature:       Integer number validation with optional min/max range
# ==================================================================================================

# =============================================================================
# INT INPUT
# =============================================================================

prompt_hint_int() {
    local min=$(input_opt "min" "")
    local max=$(input_opt "max" "")
    
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
    local min=$(input_opt "min" "")
    local max=$(input_opt "max" "")
    
    # Must be integer
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
    
    # Check range if specified
    [[ -n "$min" && "$value" -lt "$min" ]] && return 1
    [[ -n "$max" && "$value" -gt "$max" ]] && return 1
    
    return 0
}

error_msg_int() {
    local min=$(input_opt "min" "")
    local max=$(input_opt "max" "")
    
    if [[ -n "$min" && -n "$max" ]]; then
        echo "Must be an integer between $min and $max"
    elif [[ -n "$min" ]]; then
        echo "Must be an integer >= $min"
    elif [[ -n "$max" ]]; then
        echo "Must be an integer <= $max"
    else
        echo "Must be an integer"
    fi
}
