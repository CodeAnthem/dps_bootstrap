#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Input Type - Boolean
# Feature:       Yes/No boolean input prompting
# ==================================================================================================

# =============================================================================
# BOOL TYPE - Yes/No prompting
# =============================================================================

# Validate yes/no input
validate_yes_no() {
    [[ "$1" =~ ^[ynYN]$ ]]
}

# Prompt for yes/no boolean
# Usage: prompt_bool "label" "current_value"
prompt_bool() {
    local label="$1"
    local current_value="$2"
    
    while true; do
        printf "  %-20s [%s] (y/n): " "$label" "$current_value" >&2
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
        
        # Validate and normalize
        if [[ "$new_value" =~ ^[yY]$ ]]; then
            echo "y"
            return 0
        elif [[ "$new_value" =~ ^[nN]$ ]]; then
            echo "n"
            return 0
        else
            console "    Error: Please enter y or n"
            continue
        fi
    done
}
