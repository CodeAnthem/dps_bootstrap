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
    local options
    options=$(_nds_configurator_get_validator_opt "options" "")
    if [[ -n "$options" ]]; then
        echo "(${options//|/, })"
    fi
}

validate_choice() {
    local value="$1"
    local options
    options=$(_nds_configurator_get_validator_opt "options" "")
    
    # No options configured
    [[ -z "$options" ]] && return 3
    
    # Check if value matches any option
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        [[ "$value" == "$choice" ]] && return 0
    done
    
    return 1
}

error_msg_choice() {
    local value="$1"
    local code="${2:-0}"
    local options
    options=$(_nds_configurator_get_validator_opt "options" "")
    
    case "$code" in
        1)
            echo "Invalid choice. Options: ${options//|/, }"
            ;;
        3)
            echo "Configuration error: No options defined"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}
