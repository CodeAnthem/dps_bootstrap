#!/usr/bin/env bash
# ==================================================================================================
# File:          custom.sh
# Description:   Custom configuration module (simplified with callbacks)
# Author:        DPS Project
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION CALLBACK
# =============================================================================
custom_init_callback() {
    local action="$1"
    local module="$2"
    shift 2
    local config_pairs=("$@")
    
    # Default custom configuration
    local defaults=(
        "ADMIN_USER:admin"
        "SSH_PORT:22"
        "TIMEZONE:UTC"
    )
    
    # Use provided config or defaults
    if [[ ${#config_pairs[@]} -eq 0 ]]; then
        config_pairs=("${defaults[@]}")
    fi
    
    # Parse and store configuration
    for config_pair in "${config_pairs[@]}"; do
        local key="${config_pair%%:*}"
        local value_with_options="${config_pair#*:}"
        local default_value="${value_with_options%%|*}"
        local options="${value_with_options#*|}"
        
        # Store value
        config_set "$action" "$module" "$key" "$default_value"
        
        # Store options metadata
        if [[ "$options" != "$value_with_options" ]]; then
            config_set_meta "$action" "$module" "$key" "options" "$options"
        fi
        
        # Check for environment variable override
        local env_var="DPS_${key}"
        if [[ -n "${!env_var:-}" ]]; then
            config_set "$action" "$module" "$key" "${!env_var}"
            debug "Custom config override from environment: $env_var=${!env_var}"
        fi
    done
}

# =============================================================================
# MODULE DISPLAY CALLBACK
# =============================================================================
custom_display_callback() {
    local action="$1"
    local module="$2"
    
    console "Custom Configuration:"
    
    # Display all custom configuration keys
    local keys
    mapfile -t keys < <(config_get_keys "$action" "$module")
    
    for key in "${keys[@]}"; do
        local value
        value=$(config_get "$action" "$module" "$key")
        console "  $key: $value"
    done
}

# =============================================================================
# MODULE INTERACTIVE CALLBACK
# =============================================================================
custom_interactive_callback() {
    local action="$1"
    local module="$2"
    
    console "Custom Configuration:"
    
    # Get all keys
    local keys
    mapfile -t keys < <(config_get_keys "$action" "$module")
    
    for key in "${keys[@]}"; do
        local current_value
        current_value=$(config_get "$action" "$module" "$key")
        
        local options
        options=$(config_get_meta "$action" "$module" "$key" "options")
        
        # Show options if available
        if [[ -n "$options" ]]; then
            printf "  %-20s [%s] (%s): " "$key" "$current_value" "$options"
        else
            printf "  %-20s [%s]: " "$key" "$current_value"
        fi
        
        read -r new_value < /dev/tty
        
        if [[ -n "$new_value" ]]; then
            # Validate against options if provided
            if [[ -n "$options" ]] && ! validate_choice "$new_value" "$options"; then
                console "    Error: Invalid choice. Choose from: $options"
                continue
            fi
            
            # Validate specific fields
            case "$key" in
                ADMIN_USER)
                    if ! validate_username "$new_value"; then
                        console "    Error: Invalid username format"
                        continue
                    fi
                    ;;
                SSH_PORT)
                    if ! validate_port "$new_value"; then
                        console "    Error: Invalid port number (1-65535)"
                        continue
                    fi
                    ;;
                TIMEZONE)
                    if ! validate_timezone "$new_value"; then
                        console "    Warning: Timezone not found in system, but will be accepted"
                    fi
                    ;;
            esac
            
            if [[ "$new_value" != "$current_value" ]]; then
                config_set "$action" "$module" "$key" "$new_value"
                console "    -> Updated: $key = $new_value"
            else
                console "    -> Unchanged"
            fi
        fi
    done
    
    console ""
}

# =============================================================================
# FIX ERRORS CALLBACK (only prompt for invalid/missing fields)
# =============================================================================
custom_fix_errors_callback() {
    local action="$1"
    local module="$2"
    
    console "Custom Configuration:"
    console ""
    
    # Fix admin user if invalid (optional field)
    local admin_user
    admin_user=$(config_get "$action" "$module" "ADMIN_USER")
    if [[ -n "$admin_user" ]] && ! validate_username "$admin_user"; then
        local new_user
        new_user=$(prompt_validated "ADMIN_USER" "$admin_user" "validate_username" "optional" "Invalid username (lowercase, numbers, hyphens only)")
        update_if_changed "$action" "$module" "ADMIN_USER" "$admin_user" "$new_user"
    fi
    
    # Fix SSH port if invalid (optional field)
    local ssh_port
    ssh_port=$(config_get "$action" "$module" "SSH_PORT")
    if [[ -n "$ssh_port" ]] && ! validate_port "$ssh_port"; then
        local new_port
        new_port=$(prompt_number "SSH_PORT" "$ssh_port" 1 65535 "optional")
        update_if_changed "$action" "$module" "SSH_PORT" "$ssh_port" "$new_port"
    fi
    
    console ""
}

# =============================================================================
# MODULE VALIDATION CALLBACK
# =============================================================================
custom_validate_callback() {
    local action="$1"
    local module="$2"
    local validation_errors=0
    
    # Validate admin user
    local admin_user
    admin_user=$(config_get "$action" "$module" "ADMIN_USER")
    if [[ -n "$admin_user" ]] && ! validate_username "$admin_user"; then
        validation_error "Invalid admin username format: $admin_user"
        ((validation_errors++))
    fi
    
    # Validate SSH port
    local ssh_port
    ssh_port=$(config_get "$action" "$module" "SSH_PORT")
    if [[ -n "$ssh_port" ]] && ! validate_port "$ssh_port"; then
        validation_error "Invalid SSH port: $ssh_port"
        ((validation_errors++))
    fi
    
    return "$validation_errors"
}

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
# Register this module with the configurator engine
config_register_module "custom" \
    "custom_init_callback" \
    "custom_display_callback" \
    "custom_interactive_callback" \
    "custom_validate_callback" \
    "custom_fix_errors_callback"
