#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Input Type - Choice
# Feature:       Multiple choice selection from predefined options
# ==================================================================================================

# =============================================================================
# CHOICE TYPE - Multiple choice selection
# =============================================================================

# Validate choice against options
# Usage: validate_choice "value" "option1|option2|option3"
validate_choice() {
    local value="$1"
    local options="$2"

    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        if [[ "$value" == "$choice" ]]; then
            return 0
        fi
    done
    return 1
}

# Prompt for choice selection
# Usage: prompt_choice "label" "current_value" "option1|option2|option3"
prompt_choice() {
    local label="$1"
    local current_value="$2"
    local options="$3"
    
    while true; do
        printf "  %-20s [%s] (%s): " "$label" "$current_value" "${options//|/, }" >&2
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
        
        # Validate choice
        if validate_choice "$new_value" "$options"; then
            echo "$new_value"
            return 0
        else
            console "    Error: Invalid choice. Options: $options"
            continue
        fi
    done
}
