#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2026-06-30
# Description:   Input Handler - Choice
# Feature:       Multiple choice selection from predefined options
# ==================================================================================================

# =============================================================================
# CHOICE INPUT
# =============================================================================

prompt_hint_choice() {
    local options labels hint
    options=$(_nds_configurator_get_validator_opt "options" "")
    labels=$(_nds_configurator_get_validator_opt "option_labels" "")
    if [[ -n "$labels" ]]; then
        hint="("
        local pair value label
        IFS='|' read -ra pairs <<< "$labels"
        for pair in "${pairs[@]}"; do
            value="${pair%%=*}"
            label="${pair#*=}"
            hint+="${value}=${label}, "
        done
        hint="${hint%, })"
        echo "$hint"
        return 0
    fi
    if [[ -n "$options" ]]; then
        echo "(${options//|/, })"
    fi
}

display_choice() {
    local value="$1"
    local labels pair option label
    labels=$(_nds_configurator_get_validator_opt "option_labels" "")
    if [[ -n "$labels" ]]; then
        IFS='|' read -ra pairs <<< "$labels"
        for pair in "${pairs[@]}"; do
            option="${pair%%=*}"
            label="${pair#*=}"
            [[ "$value" == "$option" ]] && { echo "$label"; return 0; }
        done
    fi
    echo "$value"
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
