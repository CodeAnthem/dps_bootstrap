#!/usr/bin/env bash
# ==================================================================================================
# File:          configurator.sh
# Description:   Generic configuration engine with module callback system
# Author:        DPS Project
# ==================================================================================================

# Disable nounset for associative arrays
set +u

# =============================================================================
# GLOBAL STATE
# =============================================================================
# Single global configuration storage for all modules
declare -gA CONFIG_DATA 2>/dev/null || true

# Module registry: stores module metadata and callbacks
declare -gA MODULE_REGISTRY 2>/dev/null || true

# Registered configuration keys (for env var scanning)
declare -gA CONFIG_KEYS 2>/dev/null || true

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
# Register a configuration module
# Usage: config_register_module "network" "init_cb" "display_cb" "interactive_cb" "validate_cb" ["fix_errors_cb"]
config_register_module() {
    local module_name="$1"
    local init_callback="$2"
    local display_callback="$3"
    local interactive_callback="$4"
    local validate_callback="$5"
    local fix_errors_callback="${6:-}"
    
    MODULE_REGISTRY["${module_name}__init"]="$init_callback"
    MODULE_REGISTRY["${module_name}__display"]="$display_callback"
    MODULE_REGISTRY["${module_name}__interactive"]="$interactive_callback"
    MODULE_REGISTRY["${module_name}__validate"]="$validate_callback"
    MODULE_REGISTRY["${module_name}__fix_errors"]="$fix_errors_callback"
    MODULE_REGISTRY["${module_name}__registered"]="true"
    
    debug "Module registered: $module_name"
}

# Check if module is registered
# Usage: config_module_exists "network"
config_module_exists() {
    local module_name="$1"
    [[ "${MODULE_REGISTRY[${module_name}__registered]:-false}" == "true" ]]
}

# =============================================================================
# CONFIGURATION DATA STORAGE (CRUD OPERATIONS)
# =============================================================================
# Set configuration value
# Usage: config_set "action" "module" "key" "value"
config_set() {
    local action="$1"
    local module="$2"
    local key="$3"
    local value="$4"
    
    CONFIG_DATA["${action}__${module}__${key}"]="$value"
    
    # Register key for env var scanning
    CONFIG_KEYS["${action}__${module}__${key}"]="true"
}

# Get configuration value
# Usage: config_get "action" "module" "key"
config_get() {
    local action="$1"
    local module="$2"
    local key="$3"
    
    echo "${CONFIG_DATA[${action}__${module}__${key}]:-}"
}

# Set configuration metadata (options, validation rules, etc.)
# Usage: config_set_meta "action" "module" "key" "metadata_type" "value"
config_set_meta() {
    local action="$1"
    local module="$2"
    local key="$3"
    local meta_type="$4"
    local value="$5"
    
    CONFIG_DATA["${action}__${module}__${key}__meta__${meta_type}"]="$value"
}

# Get configuration metadata
# Usage: config_get_meta "action" "module" "key" "metadata_type"
config_get_meta() {
    local action="$1"
    local module="$2"
    local key="$3"
    local meta_type="$4"
    
    echo "${CONFIG_DATA[${action}__${module}__${key}__meta__${meta_type}]:-}"
}

# Get all keys for a module
# Usage: config_get_keys "action" "module"
config_get_keys() {
    local action="$1"
    local module="$2"
    local prefix="${action}__${module}__"
    
    local keys=()
    for key in "${!CONFIG_DATA[@]}"; do
        if [[ "$key" == ${prefix}* && "$key" != *"__meta__"* ]]; then
            local clean_key="${key#$prefix}"
            keys+=("$clean_key")
        fi
    done
    
    printf '%s\n' "${keys[@]}" | sort -u
}

# Clear all configuration for an action+module
# Usage: config_clear "action" "module"
config_clear() {
    local action="$1"
    local module="$2"
    local prefix="${action}__${module}__"
    
    for key in "${!CONFIG_DATA[@]}"; do
        if [[ "$key" == ${prefix}* ]]; then
            unset "CONFIG_DATA[$key]"
        fi
    done
}

# =============================================================================
# MODULE LIFECYCLE
# =============================================================================
# Scan and apply all DPS_* environment variables
# Usage: config_apply_env_overrides "action"
config_apply_env_overrides() {
    local action="$1"
    
    debug "Scanning for DPS_* environment variable overrides..."
    local key_count=${#CONFIG_KEYS[@]}
    debug "Registered keys count: $key_count"
    
    # Scan all registered config keys
    for config_key in "${!CONFIG_KEYS[@]}"; do
        # Extract action, module, key from config_key
        if [[ "$config_key" =~ ^${action}__([^_]+)__(.+)$ ]]; then
            local module="${BASH_REMATCH[1]}"
            local key="${BASH_REMATCH[2]}"
            local env_var="DPS_${key}"
            
            debug "Checking for $env_var (from $config_key)"
            
            # Check if environment variable exists
            if [[ -n "${!env_var:-}" ]]; then
                config_set "$action" "$module" "$key" "${!env_var}"
                log "Environment override: $env_var=${!env_var} -> $module.$key"
            fi
        fi
    done
}

# Initialize a module for an action
# Usage: config_init "action" "module" ["key:value" "key2:value|options" ...]
config_init() {
    local action="$1"
    local module="$2"
    shift 2
    local config_pairs=("$@")
    
    if ! config_module_exists "$module"; then
        error "Module not registered: $module"
        return 1
    fi
    
    # Clear existing configuration
    config_clear "$action" "$module"
    
    # Call module's init callback
    local init_callback="${MODULE_REGISTRY[${module}__init]}"
    if [[ -n "$init_callback" ]] && type "$init_callback" &>/dev/null; then
        "$init_callback" "$action" "$module" "${config_pairs[@]}"
    fi
    
    success "Configuration initialized for module: $module"
}

# Display module configuration
# Usage: config_display "action" "module"
config_display() {
    local action="$1"
    local module="$2"
    
    if ! config_module_exists "$module"; then
        error "Module not registered: $module"
        return 1
    fi
    
    local display_callback="${MODULE_REGISTRY[${module}__display]}"
    if [[ -n "$display_callback" ]] && type "$display_callback" &>/dev/null; then
        "$display_callback" "$action" "$module"
    fi
}

# Interactive configuration editing
# Usage: config_interactive "action" "module"
config_interactive() {
    local action="$1"
    local module="$2"
    
    if ! config_module_exists "$module"; then
        error "Module not registered: $module"
        return 1
    fi
    
    local interactive_callback="${MODULE_REGISTRY[${module}__interactive]}"
    if [[ -n "$interactive_callback" ]] && type "$interactive_callback" &>/dev/null; then
        "$interactive_callback" "$action" "$module"
    fi
}

# Validate module configuration
# Usage: config_validate "action" "module"
config_validate() {
    local action="$1"
    local module="$2"
    
    if ! config_module_exists "$module"; then
        error "Module not registered: $module"
        return 1
    fi
    
    local validate_callback="${MODULE_REGISTRY[${module}__validate]}"
    if [[ -n "$validate_callback" ]] && type "$validate_callback" &>/dev/null; then
        "$validate_callback" "$action" "$module"
        return $?
    fi
    
    return 0
}

# =============================================================================
# HIGH-LEVEL WORKFLOW FUNCTIONS
# =============================================================================
# Fix validation errors only (minimal prompting)
# Usage: config_fix_errors "action" "module1" "module2" ...
config_fix_errors() {
    local action="$1"
    shift
    local modules=("$@")
    
    console ""
    warn "Some configuration values are missing or invalid."
    console "Please provide the required information:"
    console ""
    
    # Only call fix_errors for modules that actually failed validation
    for module in "${modules[@]}"; do
        # First check if this module has validation errors
        if ! config_validate "$action" "$module"; then
            # This module has errors - call its fix callback
            local fix_callback="${MODULE_REGISTRY[${module}__fix_errors]}"
            if [[ -n "$fix_callback" ]] && type "$fix_callback" &>/dev/null; then
                "$fix_callback" "$action" "$module"
            else
                # Fallback: use regular interactive if no fix callback
                config_interactive "$action" "$module"
            fi
        fi
    done
}

# Interactive category selection menu
# Usage: config_menu "action" "module1" "module2" ...
config_menu() {
    local action="$1"
    shift
    local modules=("$@")
    
    while true; do
        console ""
        section_header "Configuration Menu"
        console "Select a category to modify:"
        console ""
        
        # Build menu
        local i=0
        console "  0) Done - Confirm and proceed"
        for module in "${modules[@]}"; do
            ((i++))
            # Capitalize first letter of module name
            local display_name="${module^}"
            console "  $i) $display_name Configuration"
        done
        console ""
        
        # Show current configuration
        console "Current Configuration:"
        for module in "${modules[@]}"; do
            config_display "$action" "$module"
            console ""
        done
        
        # Get selection
        printf "Select category (0-$i): "
        read -r selection < /dev/tty
        
        if [[ "$selection" == "0" ]]; then
            # Validate before confirming
            local validation_errors=0
            for module in "${modules[@]}"; do
                if ! config_validate "$action" "$module"; then
                    ((validation_errors++))
                fi
            done
            
            if [[ "$validation_errors" -gt 0 ]]; then
                console ""
                warn "Configuration still has $validation_errors error(s)."
                console "Please fix all errors before proceeding."
                continue
            fi
            
            success "Configuration confirmed"
            return 0
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "$i" ]]; then
            # Valid selection - edit that module
            local selected_module="${modules[$((selection-1))]}"
            console ""
            section_header "${selected_module^} Configuration"
            console "Press ENTER to keep current value, or type new value"
            console ""
            config_interactive "$action" "$selected_module"
            success "${selected_module^} configuration updated"
        else
            warn "Invalid selection. Please enter a number between 0 and $i."
        fi
    done
}

# Complete configuration workflow for an action
# Usage: config_workflow "action" "module1" "module2" ...
config_workflow() {
    local action="$1"
    shift
    local modules=("$@")
    
    # Apply environment variable overrides FIRST
    config_apply_env_overrides "$action"
    
    # Validate all modules BEFORE first display
    local validation_errors=0
    for module in "${modules[@]}"; do
        if ! config_validate "$action" "$module"; then
            ((validation_errors++))
        fi
    done
    
    # If validation fails, fix errors only (not all fields)
    if [[ "$validation_errors" -gt 0 ]]; then
        config_fix_errors "$action" "${modules[@]}"
        
        # Re-validate after fixes
        validation_errors=0
        for module in "${modules[@]}"; do
            if ! config_validate "$action" "$module"; then
                ((validation_errors++))
            fi
        done
        
        if [[ "$validation_errors" -gt 0 ]]; then
            error "Configuration validation still has $validation_errors error(s)"
        fi
        
        success "Required fields completed"
    fi
    
    # Display all configurations
    console ""
    section_header "Configuration Summary"
    for module in "${modules[@]}"; do
        config_display "$action" "$module"
        console ""
    done
    
    # Ask if user wants to modify anything
    while true; do
        printf "Do you want to modify any settings? [y/n]: "
        read -r response < /dev/tty
        
        case "${response,,}" in
            y|yes)
                # Show interactive menu
                config_menu "$action" "${modules[@]}"
                
                # After menu, show updated config
                console ""
                section_header "Configuration Summary"
                for module in "${modules[@]}"; do
                    config_display "$action" "$module"
                    console ""
                done
                ;;
            n|no)
                success "Configuration confirmed"
                return 0
                ;;
            "")
                console "Please enter 'y' to modify or 'n' to confirm"
                ;;
            *)
                console "Invalid input. Please enter 'y' or 'n'"
                ;;
        esac
    done
}


# =============================================================================
# DYNAMIC CONFIGURATION (FOR SETUP SCRIPTS)
# =============================================================================
# Register custom variables for an action (bypasses module system)
# Usage: config_register_vars "action" "VAR1:default1" "VAR2:default2" ...
config_register_vars() {
    local action="$1"
    shift
    local module="custom"
    
    for var_spec in "$@"; do
        local key="${var_spec%%:*}"
        local default_value="${var_spec#*:}"
        
        # Set default value
        config_set "$action" "$module" "$key" "$default_value"
        
        # Check for environment variable override
        local env_var="DPS_${key}"
        if [[ -n "${!env_var:-}" ]]; then
            config_set "$action" "$module" "$key" "${!env_var}"
            debug "Custom var override: $env_var=${!env_var}"
        fi
    done
}

# Get custom variable value
# Usage: config_get_var "action" "VAR_NAME"
config_get_var() {
    local action="$1"
    local key="$2"
    config_get "$action" "custom" "$key"
}
