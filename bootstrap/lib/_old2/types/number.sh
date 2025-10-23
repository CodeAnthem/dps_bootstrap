#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Input Type - Number
# Feature:       Numeric input with range validation
# ==================================================================================================

# =============================================================================
# NUMBER TYPE - Numeric input with optional range
# =============================================================================

# Prompt for numeric input
# Usage: prompt_number "label" "current_value" "validator"
prompt_number() {
    local label="$1"
    local current_value="$2"
    local validator="${3:-validate_number}"
    
    while true; do
        printf "  %-20s [%s]: " "$label" "$current_value" >&2
        read -r new_value < /dev/tty
        
        # Empty input - keep current
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                echo "$current_value"
                return 0
            else
                console "    Error: $label is required"
                continue
            fi
        fi
        
        # Validate number
        if $validator "$new_value"; then
            echo "$new_value"
            return 0
        else
            console "    Error: Invalid number"
            continue
        fi
    done
}

# Generic number validator (any positive integer)
validate_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}
