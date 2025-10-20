#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Custom Configuration Module
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-20 | Modified: 2025-10-20
# Description:   Generic custom configuration module for action-specific settings
# Feature:       Flexible key-value configuration, environment variable override
# Author:        DPS Project
# ==================================================================================================

# Disable nounset for this module - associative arrays don't work well with set -u
set +u

# =============================================================================
# CUSTOM CONFIGURATION STORAGE
# =============================================================================
declare -A CUSTOM_CONFIG

# =============================================================================
# CUSTOM CONFIGURATION FUNCTIONS
# =============================================================================
# Initialize custom configuration
# Usage: custom_config_init "actionName" "KEY:default_value" "KEY2:option1|option2|option3"
custom_config_init() {
    local action_name="$1"
    shift
    
    # Clear existing custom config for this action
    for key in $(custom_config_get_keys "$action_name" 2>/dev/null || true); do
        local clear_key="${action_name}__${key}"
        unset "CUSTOM_CONFIG[$clear_key]"
    done
    
    # Initialize configuration with provided key-value pairs
    for config_pair in "$@"; do
        local key="${config_pair%%:*}"
        local value_with_options="${config_pair#*:}"
        
        # Parse options if they exist (format: "default|option2|option3")
        local default_value="${value_with_options%%|*}"
        local options=""
        if [[ "$value_with_options" == *"|"* ]]; then
            options="${value_with_options#*|}"
        fi
        
        # Store the configuration
        local value_key="${action_name}__${key}__value"
        local options_key="${action_name}__${key}__options"
        CUSTOM_CONFIG[$value_key]="$default_value"
        CUSTOM_CONFIG[$options_key]="$options"
        
        # Check if environment variable exists and override (with DPS_ prefix)
        local env_var_name="DPS_${key}"
        if [[ -n "${!env_var_name:-}" ]]; then
            local env_value="${!env_var_name}"
            CUSTOM_CONFIG[$value_key]="$env_value"
            debug "Custom config override from environment: $env_var_name=$env_value"
        fi
    done
    
    debug "Custom configuration initialized for action: $action_name"
}

# Get custom configuration value
# Usage: custom_config_get "actionName" "KEY"
custom_config_get() {
    local action_name="$1"
    local key="$2"
    local get_key="${action_name}__${key}__value"
    echo "${CUSTOM_CONFIG[$get_key]:-}"
}

# Get custom configuration options
# Usage: custom_config_get_options "actionName" "KEY"
custom_config_get_options() {
    local action_name="$1"
    local key="$2"
    local options_key="${action_name}__${key}__options"
    echo "${CUSTOM_CONFIG[$options_key]:-}"
}

# Set custom configuration value
# Usage: custom_config_set "actionName" "KEY" "value"
custom_config_set() {
    local action_name="$1"
    local key="$2"
    local value="$3"
    local set_key="${action_name}__${key}__value"
    CUSTOM_CONFIG[$set_key]="$value"
}

# Get all custom configuration keys for an action
# Usage: custom_config_get_keys "actionName"
custom_config_get_keys() {
    local action_name="$1"
    local prefix="${action_name}__"
    
    for key in "${!CUSTOM_CONFIG[@]}"; do
        if [[ "$key" == "$prefix"*"__value" ]]; then
            local clean_key="${key#$prefix}"
            echo "${clean_key%__value}"
        fi
    done
}

# =============================================================================
# CUSTOM CONFIGURATION DISPLAY
# =============================================================================
# Display custom configuration
# Usage: custom_config_display "actionName"
custom_config_display() {
    local action_name="$1"
    local keys
    
    # Get all keys for this action
    mapfile -t keys < <(custom_config_get_keys "$action_name" | sort)
    
    if [[ ${#keys[@]} -eq 0 ]]; then
        return 0  # No custom config to display
    fi
    
    console "Custom Configuration:"
    
    for key in "${keys[@]}"; do
        local value options
        value=$(custom_config_get "$action_name" "$key")
        options=$(custom_config_get_options "$action_name" "$key")
        
        # Show empty values as "(required)"
        if [[ -z "$value" ]]; then
            value="(required)"
        fi
        
        # Show options if available
        if [[ -n "$options" ]]; then
            console "  $key: $value (options: ${options//|/, })"
        else
            console "  $key: $value"
        fi
    done
}

# =============================================================================
# CUSTOM CONFIGURATION INTERACTIVE
# =============================================================================
# Interactive custom configuration editing
# Usage: custom_config_interactive "actionName"
custom_config_interactive() {
    local action_name="$1"
    local keys
    
    # Get all keys for this action
    mapfile -t keys < <(custom_config_get_keys "$action_name" | sort)
    
    if [[ ${#keys[@]} -eq 0 ]]; then
        return 0  # No custom config to edit
    fi
    
    console ""
    console "Custom Configuration:"
    
    for key in "${keys[@]}"; do
        local current_value options
        current_value=$(custom_config_get "$action_name" "$key")
        options=$(custom_config_get_options "$action_name" "$key")
        
        # Show current value or "(required)" if empty
        local display_value="$current_value"
        if [[ -z "$current_value" ]]; then
            display_value="(required)"
        fi
        
        # Show available options
        if [[ -n "$options" ]]; then
            console "  Available options for $key: ${options//|/, }"
        fi
        
        # Prompt for new value with validation loop
        while true; do
            local new_value
            printf "  %-20s [%s]: " "$key" "$display_value"
            read -r new_value < /dev/tty
            
            # If user entered nothing, keep current value
            if [[ -z "$new_value" ]]; then
                if [[ -z "$current_value" ]]; then
                    console "    Error: Required field '$key' cannot be empty"
                    continue
                fi
                break
            fi
            
            # Validate against options if they exist
            if [[ -n "$options" ]]; then
                local valid_option=false
                IFS='|' read -ra option_array <<< "$options"
                for option in "${option_array[@]}"; do
                    if [[ "$new_value" == "$option" ]]; then
                        valid_option=true
                        break
                    fi
                done
                
                if [[ "$valid_option" == false ]]; then
                    console "    Error: Invalid option '$new_value'. Valid options: ${options//|/, }"
                    continue
                fi
            fi
            
            # Valid input, update configuration
            custom_config_set "$action_name" "$key" "$new_value"
            console "    -> Updated: $key = $new_value"
            break
        done
    done
}

# =============================================================================
# CUSTOM CONFIGURATION VALIDATION
# =============================================================================
# Validate custom configuration
# Usage: custom_config_validate "actionName"
custom_config_validate() {
    local action_name="$1"
    local keys
    local validation_errors=0
    
    # Get all keys for this action
    mapfile -t keys < <(custom_config_get_keys "$action_name")
    
    for key in "${keys[@]}"; do
        local value options
        value=$(custom_config_get "$action_name" "$key")
        options=$(custom_config_get_options "$action_name" "$key")
        
        # Check required fields
        if [[ -z "$value" ]]; then
            error "Required custom configuration missing: $key"
            ((validation_errors++))
            continue
        fi
        
        # Validate against options if they exist
        if [[ -n "$options" ]]; then
            local valid_option=false
            IFS='|' read -ra option_array <<< "$options"
            for option in "${option_array[@]}"; do
                if [[ "$value" == "$option" ]]; then
                    valid_option=true
                    break
                fi
            done
            
            if [[ "$valid_option" == false ]]; then
                error "Invalid custom configuration value for $key: '$value'. Valid options: ${options//|/, }"
                ((validation_errors++))
            fi
        fi
    done
    
    if [[ $validation_errors -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# =============================================================================
# CUSTOM CONFIGURATION GETTERS
# =============================================================================
# Get DPS variable name for a key
# Usage: custom_config_get_var_name "KEY"
custom_config_get_var_name() {
    local key="$1"
    echo "DPS_${key}"
}

# Get configuration value by key (with action context)
# Usage: custom_config_get_value "actionName" "KEY"
custom_config_get_value() {
    local action_name="$1"
    local key="$2"
    custom_config_get "$action_name" "$key"
}
