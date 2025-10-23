#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Input Type - Text
# Feature:       Generic text input with validation
# ==================================================================================================

# =============================================================================
# TEXT TYPE - Generic validated text input
# =============================================================================

# Prompt for text input with validation
# Usage: prompt_validated "label" "current_value" "validation_function" ["required"|"optional"] ["error_message"]
prompt_validated() {
    local label="$1"
    local current_value="$2"
    local validation_func="$3"
    local required="${4:-optional}"
    local error_msg="${5:-Invalid input}"
    
    while true; do
        printf "  %-20s [%s]: " "$label" "$current_value" >&2
        read -r new_value < /dev/tty
        
        # Empty input handling
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                # Keep current value
                echo "$current_value"
                return 0
            elif [[ "$required" == "optional" ]]; then
                # Optional field, accept empty
                echo ""
                return 0
            else
                # Required field, empty not allowed
                console "    Error: $label is required"
                continue
            fi
        fi
        
        # Validate new input
        if $validation_func "$new_value"; then
            echo "$new_value"
            return 0
        else
            console "    Error: $error_msg"
            continue
        fi
    done
}
