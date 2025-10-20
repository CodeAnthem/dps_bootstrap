#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Configuration Management Library
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-20 | Modified: 2025-10-20
# Description:   Smart configuration management for all bootstrap actions
# Feature:       Dynamic config arrays, environment variable override, interactive configuration
# Author:        DPS Project
# ==================================================================================================

# =============================================================================
# GLOBAL CONFIGURATION STORAGE
# =============================================================================
# Global associative array to store all action configurations
declare -A CONFIG_STORE

# =============================================================================
# CONFIGURATION INITIALIZATION
# =============================================================================
# Initialize configuration for an action
# Usage: config_init "actionName" "KEY1:default_value1" "KEY2:" "KEY3:default_value3"
config_init() {
    local action_name="$1"
    shift
    
    # Clear any existing configuration for this action
    for key in $(config_get_keys "$action_name" 2>/dev/null || true); do
        unset "CONFIG_STORE[${action_name}:${key}]"
    done
    
    # Initialize configuration with provided key-value pairs
    for config_pair in "$@"; do
        local key="${config_pair%%:*}"
        local default_value="${config_pair#*:}"
        
        # Store the default value
        CONFIG_STORE["${action_name}:${key}"]="$default_value"
        
        # Check if environment variable exists and override
        local env_var_name="$key"
        if [[ -n "${!env_var_name:-}" ]]; then
            CONFIG_STORE["${action_name}:${key}"]="${!env_var_name}"
            debug "Config override from environment: $key=${!env_var_name}"
        fi
    done
    
    log "Configuration initialized for action: $action_name"
}

# =============================================================================
# CONFIGURATION GETTERS/SETTERS
# =============================================================================
# Get configuration value
# Usage: config_get "actionName" "KEY"
config_get() {
    local action_name="$1"
    local key="$2"
    echo "${CONFIG_STORE["${action_name}:${key}"]:-}"
}

# Set configuration value
# Usage: config_set "actionName" "KEY" "value"
config_set() {
    local action_name="$1"
    local key="$2"
    local value="$3"
    CONFIG_STORE["${action_name}:${key}"]="$value"
}

# Get all configuration keys for an action
# Usage: config_get_keys "actionName"
config_get_keys() {
    local action_name="$1"
    local prefix="${action_name}:"
    
    for key in "${!CONFIG_STORE[@]}"; do
        if [[ "$key" == "$prefix"* ]]; then
            echo "${key#$prefix}"
        fi
    done
}

# =============================================================================
# CONFIGURATION DISPLAY
# =============================================================================
# Display configuration in a nice tabbed table
# Usage: config_display "actionName"
config_display() {
    local action_name="$1"
    local keys
    
    # Get all keys for this action
    mapfile -t keys < <(config_get_keys "$action_name" | sort)
    
    if [[ ${#keys[@]} -eq 0 ]]; then
        console "No configuration found for action: $action_name"
        return 1
    fi
    
    new_section
    section_header "Configuration for $action_name"
    
    # Calculate maximum key length for alignment
    local max_key_length=0
    for key in "${keys[@]}"; do
        if [[ ${#key} -gt $max_key_length ]]; then
            max_key_length=${#key}
        fi
    done
    
    # Display configuration table
    # printf "%-${max_key_length}s | %s\n" "Configuration Key" "Current Value"
    # printf "%*s-+-%s\n" "$max_key_length" "" "$(printf '%*s' 50 '' | tr ' ' '-')"
    
    for key in "${keys[@]}"; do
        local value
        value=$(config_get "$action_name" "$key")
        
        # Show empty values as "(required)"
        if [[ -z "$value" ]]; then
            value="(required)"
        fi
        
        printf "%-${max_key_length}s | %s\n" "$key" "$value"
    done
    
    console ""
}

# =============================================================================
# INTERACTIVE CONFIGURATION
# =============================================================================
# Interactive configuration review and editing
# Usage: config_interactive "actionName"
config_interactive() {
    local action_name="$1"
    local keys
    
    # Get all keys for this action
    mapfile -t keys < <(config_get_keys "$action_name" | sort)
    
    if [[ ${#keys[@]} -eq 0 ]]; then
        error "No configuration found for action: $action_name"
        return 1
    fi
    
    new_section
    section_header "Interactive Configuration for $action_name"
    
    console "Review and modify configuration values:"
    console "Press ENTER to keep current value, or type new value"
    console ""
    
    for key in "${keys[@]}"; do
        local current_value
        current_value=$(config_get "$action_name" "$key")
        
        # Show current value or "(required)" if empty
        local display_value="$current_value"
        if [[ -z "$current_value" ]]; then
            display_value="(required)"
        fi
        
        # Prompt for new value
        local new_value
        printf "%-20s [%s]: " "$key" "$display_value"
        read -r new_value < /dev/tty
        
        # If user entered something, update the value
        if [[ -n "$new_value" ]]; then
            config_set "$action_name" "$key" "$new_value"
            console "  -> Updated: $key = $new_value"
        elif [[ -z "$current_value" ]]; then
            # Required field left empty
            error "Required field '$key' cannot be empty"
            return 1
        fi
    done
    
    success "Configuration review completed"
}

# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================
# Validate all required fields are set
# Usage: config_validate "actionName"
config_validate() {
    local action_name="$1"
    local keys
    local validation_errors=0
    
    # Get all keys for this action
    mapfile -t keys < <(config_get_keys "$action_name")
    
    for key in "${keys[@]}"; do
        local value
        value=$(config_get "$action_name" "$key")
        
        if [[ -z "$value" ]]; then
            error "Required configuration missing: $key"
            ((validation_errors++))
        fi
    done
    
    if [[ $validation_errors -gt 0 ]]; then
        error "Configuration validation failed: $validation_errors missing values"
        return 1
    fi
    
    success "Configuration validation passed"
    return 0
}

# =============================================================================
# CONFIGURATION EXPORT
# =============================================================================
# Export all configuration values as environment variables
# Usage: config_export "actionName"
config_export() {
    local action_name="$1"
    local keys
    
    # Get all keys for this action
    mapfile -t keys < <(config_get_keys "$action_name")
    
    for key in "${keys[@]}"; do
        local value
        value=$(config_get "$action_name" "$key")
        
        if [[ -n "$value" ]]; then
            export "$key"="$value"
            debug "Exported: $key=$value"
        fi
    done
    
    log "Configuration exported as environment variables"
}

# =============================================================================
# VALIDATION HELPER FUNCTIONS
# =============================================================================
# Validate IP address format
# Usage: validate_ip_address "192.168.1.1"
validate_ip_address() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "$ip" =~ $ip_regex ]]; then
        return 1
    fi
    
    # Check each octet is 0-255
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if ((octet < 0 || octet > 255)); then
            return 1
        fi
    done
    
    return 0
}

# Validate hostname format
# Usage: validate_hostname "my-host"
validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
    
    [[ "$hostname" =~ $hostname_regex ]]
}

# Validate disk path exists
# Usage: validate_disk_path "/dev/sda"
validate_disk_path() {
    local disk_path="$1"
    
    [[ -b "$disk_path" ]]
}

# Validate yes/no input
# Usage: validate_yes_no "y"
validate_yes_no() {
    local input="$1"
    local normalized="${input,,}"  # Convert to lowercase
    
    [[ "$normalized" =~ ^(y|yes|n|no)$ ]]
}

# =============================================================================
# CONFIGURATION WORKFLOW
# =============================================================================
# Complete configuration workflow: display -> interactive -> validate -> export
# Usage: config_workflow "actionName"
config_workflow() {
    local action_name="$1"
    
    # Display current configuration
    config_display "$action_name"
    
    # Ask if user wants to modify configuration
    local modify_config
    printf "Do you want to modify the configuration? [y/N]: "
    read -rn1 modify_config < /dev/tty
    echo  # Add newline
    
    if [[ "${modify_config,,}" == "y" ]]; then
        config_interactive "$action_name"
        echo
        config_display "$action_name"
    fi
    
    # Validate configuration
    if ! config_validate "$action_name"; then
        error "Configuration validation failed"
        return 1
    fi
    
    # Export configuration
    config_export "$action_name"
    
    success "Configuration workflow completed for $action_name"
}
