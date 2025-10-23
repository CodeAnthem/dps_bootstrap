#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Choice
# Feature:       Multiple choice selection from predefined options
# ==================================================================================================

# =============================================================================
# CHOICE INPUT
# =============================================================================

prompt_hint_choice() {
    local options=$(input_opt "options" "")
    if [[ -n "$options" ]]; then
        echo "(${options//|/, })"
    fi
}

validate_choice() {
    local value="$1"
    local options=$(input_opt "options" "")
    
    [[ -z "$options" ]] && return 1
    
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        [[ "$value" == "$choice" ]] && return 0
    done
    
    return 1
}

error_msg_choice() {
    local options=$(input_opt "options" "")
    echo "Invalid choice. Options: ${options//|/, }"
}
