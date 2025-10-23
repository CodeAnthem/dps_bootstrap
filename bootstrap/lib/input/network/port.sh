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
    local min=$(input_opt "min" "1")
    local max=$(input_opt "max" "65535")
    echo "($min-$max)"
}

validate_port() {
    local value="$1"
    local min=$(input_opt "min" "1")
    local max=$(input_opt "max" "65535")
    
    [[ "$value" =~ ^[0-9]+$ ]] && (( value >= min && value <= max ))
}

error_msg_port() {
    local min=$(input_opt "min" "1")
    local max=$(input_opt "max" "65535")
    echo "Port must be a number between $min and $max"
}
