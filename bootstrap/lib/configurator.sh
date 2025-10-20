#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Configuration Management Orchestrator
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-20 | Modified: 2025-10-20
# Description:   Main configuration orchestrator with module hooks and workflow management
# Feature:       Module loading, configuration workflow, validation hooks, iterative configuration
# Author:        DPS Project
# ==================================================================================================

# =============================================================================
# CONFIGURATION MODULES
# =============================================================================
# Module status tracking
declare -A CONFIG_MODULES_ENABLED

# Source configuration modules
readonly CONFIGURATOR_MODULES_DIR="${SCRIPT_DIR}/lib/configurator_modules"

# Load configuration modules
source_config_module() {
    local module_name="$1"
    local module_path="${CONFIGURATOR_MODULES_DIR}/configuration_${module_name}.sh"
    
    if [[ -f "$module_path" ]]; then
        # shellcheck disable=SC1090
        source "$module_path"
        debug "Configuration module loaded: $module_name"
    else
        error "Configuration module not found: $module_path"
        return 1
    fi
}

# Enable configuration modules
# Usage: config_enable_modules "network" "disk" "custom"
config_enable_modules() {
    for module in "$@"; do
        source_config_module "$module"
        CONFIG_MODULES_ENABLED["$module"]=true
        debug "Configuration module enabled: $module"
    done
}

# =============================================================================
# CONFIGURATION INITIALIZATION
# =============================================================================
# Initialize all enabled modules for an action
# Usage: config_init "actionName" ["custom_config_pairs..."]
config_init() {
    local action_name="$1"
    shift
    
    # Initialize network module if enabled
    if [[ "${CONFIG_MODULES_ENABLED[network]:-}" == "true" ]]; then
        network_config_init "$action_name"
    fi
    
    # Initialize disk module if enabled
    if [[ "${CONFIG_MODULES_ENABLED[disk]:-}" == "true" ]]; then
        disk_config_init "$action_name"
    fi
    
    # Initialize custom module if enabled and has config pairs
    if [[ "${CONFIG_MODULES_ENABLED[custom]:-}" == "true" && $# -gt 0 ]]; then
        custom_config_init "$action_name" "$@"
    fi
    
    success "Configuration initialized for action: $action_name"
}

# =============================================================================
# CONFIGURATION DISPLAY
# =============================================================================
# Display all enabled module configurations
# Usage: config_display "actionName"
config_display() {
    local action_name="$1"
    
    new_section
    section_header "Confirm the configuration"
    
    # Display network configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[network]:-}" == "true" ]]; then
        network_config_display "$action_name"
        console ""
    fi
    
    # Display disk configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[disk]:-}" == "true" ]]; then
        disk_config_display "$action_name"
        console ""
    fi
    
    # Display custom configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[custom]:-}" == "true" ]]; then
        custom_config_display "$action_name"
        console ""
    fi
}

# =============================================================================
# CONFIGURATION INTERACTIVE
# =============================================================================
# Interactive configuration for all enabled modules
# Usage: config_interactive "actionName"
config_interactive() {
    local action_name="$1"
    
    new_section
    section_header "Interactive Configuration"
    
    console "Review and modify configuration values:"
    console "Press ENTER to keep current value, or type new value"
    
    # Interactive network configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[network]:-}" == "true" ]]; then
        network_config_interactive "$action_name"
    fi
    
    # Interactive disk configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[disk]:-}" == "true" ]]; then
        disk_config_interactive "$action_name"
    fi
    
    # Interactive custom configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[custom]:-}" == "true" ]]; then
        custom_config_interactive "$action_name"
    fi
    
    success "Interactive configuration completed"
}

# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================
# Validate all enabled module configurations
# Usage: config_validate "actionName"
config_validate() {
    local action_name="$1"
    local validation_errors=0
    
    # Validate network configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[network]:-}" == "true" ]]; then
        if ! network_config_validate "$action_name"; then
            ((validation_errors++))
        fi
    fi
    
    # Validate disk configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[disk]:-}" == "true" ]]; then
        if ! disk_config_validate "$action_name"; then
            ((validation_errors++))
        fi
    fi
    
    # Validate custom configuration if enabled
    if [[ "${CONFIG_MODULES_ENABLED[custom]:-}" == "true" ]]; then
        if ! custom_config_validate "$action_name"; then
            ((validation_errors++))
        fi
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        error "Configuration validation failed: $validation_errors module(s) have errors"
        return 1
    fi
    
    success "Configuration validation passed"
    return 0
}

# =============================================================================
# CONFIGURATION WORKFLOW
# =============================================================================
# Complete configuration workflow with iterative editing
# Usage: config_workflow "actionName"
config_workflow() {
    local action_name="$1"
    
    # Check if DPS_AUTO_CONFIRM is set to skip interactive configuration
    if [[ "${DPS_AUTO_CONFIRM:-}" == "true" ]]; then
        log "Auto-confirm enabled, skipping interactive configuration"
        return config_validate "$action_name"
    fi
    
    while true; do
        # Display current configuration
        config_display "$action_name"
        
        # Ask if user wants to modify configuration
        local modify_config
        printf "Do you want to modify the configuration? [y/N]: "
        read -rn1 modify_config < /dev/tty
        echo  # Add newline
        
        if [[ "${modify_config,,}" == "y" ]]; then
            # Interactive configuration editing
            config_interactive "$action_name"
            
            # Validate after changes
            if config_validate "$action_name"; then
                # Show updated configuration and ask again
                continue
            else
                console "Configuration has validation errors. Please fix them."
                continue
            fi
        else
            # User doesn't want to modify, validate current config
            if config_validate "$action_name"; then
                break
            else
                console "Current configuration has validation errors."
                console "You must fix these errors before proceeding."
                continue
            fi
        fi
    done
    
    success "Configuration workflow completed for $action_name"
}

# =============================================================================
# CONFIGURATION GETTERS
# =============================================================================
# Get configuration value from any enabled module
# Usage: config_get_value "actionName" "KEY"
config_get_value() {
    local action_name="$1"
    local key="$2"
    local value=""
    
    # Try network module first
    if [[ "${CONFIG_MODULES_ENABLED[network]:-}" == "true" ]]; then
        value=$(network_config_get_value "$action_name" "$key" 2>/dev/null || true)
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi
    
    # Try disk module
    if [[ "${CONFIG_MODULES_ENABLED[disk]:-}" == "true" ]]; then
        value=$(disk_config_get_value "$action_name" "$key" 2>/dev/null || true)
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi
    
    # Try custom module
    if [[ "${CONFIG_MODULES_ENABLED[custom]:-}" == "true" ]]; then
        value=$(custom_config_get_value "$action_name" "$key" 2>/dev/null || true)
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi
    
    # Key not found in any module
    return 1
}

# Get DPS variable name for any key
# Usage: config_get_var_name "KEY"
config_get_var_name() {
    local key="$1"
    echo "DPS_${key}"
}

# =============================================================================
# VALIDATION HELPER FUNCTIONS (shared across modules)
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
