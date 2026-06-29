#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Port Number
# Feature:       Port number validation with configurable min/max range
# ==================================================================================================

# =============================================================================
# PORT INPUT
# =============================================================================

prompt_hint_port() {
    local min max
    min=$(_nds_configurator_get_validator_opt "min" "1")
    max=$(_nds_configurator_get_validator_opt "max" "65535")
    echo "($min-$max)"
}

validate_port() {
    local value="$1"
    local min max
    min=$(_nds_configurator_get_validator_opt "min" "1")
    max=$(_nds_configurator_get_validator_opt "max" "65535")
    
    # Must be numeric
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    
    # Check range
    (( value >= min && value <= max )) || return 2
    
    return 0
}

error_msg_port() {
    local value="$1"
    local code="${2:-0}"
    local min max
    min=$(_nds_configurator_get_validator_opt "min" "1")
    max=$(_nds_configurator_get_validator_opt "max" "65535")
    
    case "$code" in
        1)
            echo "Port must be numeric (no letters or special characters)"
            ;;
        2)
            echo "Port must be between $min and $max"
            ;;
        *)
            echo "Invalid port number"
            ;;
    esac
}
