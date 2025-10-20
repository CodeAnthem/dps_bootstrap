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

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
# Register a configuration module
# Usage: config_register_module "network" "init_callback" "display_callback" "interactive_callback" "validate_callback"
config_register_module() {
    local module_name="$1"
    local init_callback="$2"
    local display_callback="$3"
    local interactive_callback="$4"
    local validate_callback="$5"
    
    MODULE_REGISTRY["${module_name}__init"]="$init_callback"
    MODULE_REGISTRY["${module_name}__display"]="$display_callback"
    MODULE_REGISTRY["${module_name}__interactive"]="$interactive_callback"
    MODULE_REGISTRY["${module_name}__validate"]="$validate_callback"
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
# Complete configuration workflow for an action
# Usage: config_workflow "action" "module1" "module2" ...
config_workflow() {
    local action="$1"
    shift
    local modules=("$@")
    
    # Display all configurations
    print_box "Confirm the configuration"
    for module in "${modules[@]}"; do
        config_display "$action" "$module"
        console ""
    done
    
    # Ask for modifications
    while true; do
        printf "Do you want to modify the configuration? [y/N]: "
        read -r response < /dev/tty
        
        case "${response,,}" in
            y|yes)
                print_box "Interactive Configuration"
                console "Review and modify configuration values:"
                console "Press ENTER to keep current value, or type new value"
                console ""
                
                for module in "${modules[@]}"; do
                    config_interactive "$action" "$module"
                done
                
                success "Interactive configuration completed"
                
                # Validate all modules
                local validation_errors=0
                for module in "${modules[@]}"; do
                    if ! config_validate "$action" "$module"; then
                        ((validation_errors++))
                    fi
                done
                
                if [[ "$validation_errors" -gt 0 ]]; then
                    error "Configuration validation failed with $validation_errors error(s)"
                    continue
                fi
                
                success "Configuration validation passed"
                
                # Show updated configuration
                print_box "Confirm the configuration"
                for module in "${modules[@]}"; do
                    config_display "$action" "$module"
                    console ""
                done
                ;;
            n|no|"")
                success "Configuration confirmed"
                return 0
                ;;
            *)
                console "Invalid input. Please enter 'y' or 'n'"
                ;;
        esac
    done
}

# Initialize all modules for an action with default values
# Usage: config_init_all "action" "module1:key1:val1|key2:val2" "module2:key1:val1"
config_init_all() {
    local action="$1"
    shift
    
    for module_spec in "$@"; do
        local module="${module_spec%%:*}"
        local config_string="${module_spec#*:}"
        
        # Parse config pairs
        IFS='|' read -ra config_pairs <<< "$config_string"
        
        config_init "$action" "$module" "${config_pairs[@]}"
    done
}
