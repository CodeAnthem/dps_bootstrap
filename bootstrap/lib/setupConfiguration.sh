#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS Configuration System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Description:   Generic configuration system with field-based metadata
# Architecture:  Module declares fields → Generic validation/prompting → Smart workflow
# ==================================================================================================

# =============================================================================
# GLOBAL STATE
# =============================================================================
# Current module context (set during init)
declare -g MODULE_CONTEXT=""

# Field metadata registry: module__field__attribute → value
declare -gA FIELD_REGISTRY 2>/dev/null || true

# Configuration data storage: module__field → value
declare -gA CONFIG_DATA 2>/dev/null || true

# Module registry: stores module callbacks
declare -gA MODULE_REGISTRY 2>/dev/null || true

# =============================================================================
# FIELD METADATA MANAGEMENT
# =============================================================================

# Declare a field with metadata (uses MODULE_CONTEXT)
# Usage: field_declare HOSTNAME display="Hostname" required=true validator=validate_hostname
field_declare() {
    local field_name="$1"
    shift
    local module="${MODULE_CONTEXT}"
    
    if [[ -z "$module" ]]; then
        error "field_declare called without MODULE_CONTEXT set"
        return 1
    fi
    
    # Parse key=value attributes
    for attr in "$@"; do
        local key="${attr%%=*}"
        local value="${attr#*=}"
        FIELD_REGISTRY["${module}__${field_name}__${key}"]="$value"
    done
    
    # Set default value if provided
    local default="${FIELD_REGISTRY[${module}__${field_name}__default]:-}"
    config_set "$module" "$field_name" "$default"
    
    debug "Field declared: $module.$field_name"
}

# Get field metadata attribute
# Usage: field_get "module" "field" "attribute"
field_get() {
    local module="$1"
    local field="$2"
    local attribute="$3"
    
    echo "${FIELD_REGISTRY[${module}__${field}__${attribute}]:-}"
}

# Check if field exists
# Usage: field_exists "module" "field"
field_exists() {
    local module="$1"
    local field="$2"
    
    [[ -n "${FIELD_REGISTRY[${module}__${field}__display]:-}" ]]
}

# =============================================================================
# CONFIG DATA STORAGE
# =============================================================================

# Set configuration value
# Usage: config_set "module" "field" "value"
config_set() {
    local module="$1"
    local key="$2"
    local value="$3"
    
    CONFIG_DATA["${module}__${key}"]="$value"
    debug "Config set: $module.$key = $value"
}

# Get configuration value
# Usage: config_get "module" "field" OR config_get "field" (uses MODULE_CONTEXT)
config_get() {
    if [[ $# -eq 1 ]]; then
        # Single arg: use MODULE_CONTEXT
        local module="${MODULE_CONTEXT}"
        local key="$1"
    else
        # Two args: explicit module
        local module="$1"
        local key="$2"
    fi
    
    echo "${CONFIG_DATA[${module}__${key}]:-}"
}

# Apply DPS_* environment variable overrides for a module
# Usage: config_apply_env_overrides "module"
config_apply_env_overrides() {
    local module="$1"
    
    debug "Scanning for DPS_* environment variable overrides for module: $module"
    
    # Iterate over all fields in this module
    for key in "${!FIELD_REGISTRY[@]}"; do
        # Match pattern: module__FIELD_NAME__display (field name can contain underscores)
        if [[ "$key" =~ ^${module}__(.+)__display$ ]]; then
            local field_name="${BASH_REMATCH[1]}"
            local env_var="DPS_${field_name}"
            
            if [[ -n "${!env_var:-}" ]]; then
                config_set "$module" "$field_name" "${!env_var}"
                log "Environment override: $env_var=${!env_var} -> $module.$field_name"
            fi
        fi
    done
}

# =============================================================================
# GENERIC FIELD OPERATIONS
# =============================================================================

# Validate one field
# Usage: field_validate "module" "field"
field_validate() {
    local module="$1"
    local field="$2"
    
    local value=$(config_get "$module" "$field")
    local required=$(field_get "$module" "$field" "required")
    local validator=$(field_get "$module" "$field" "validator")
    local type=$(field_get "$module" "$field" "type")
    local display=$(field_get "$module" "$field" "display")
    
    # Check if required and empty
    if [[ "$required" == "true" && -z "$value" ]]; then
        validation_error "$display is required"
        return 1
    fi
    
    # Auto-detect validator based on type if not specified
    if [[ -z "$validator" ]]; then
        case "$type" in
            choice) validator="validate_choice" ;;
            number) validator="validate_number" ;;
            bool) validator="validate_yes_no" ;;
        esac
    fi
    
    # Run validator if value present and validator exists
    if [[ -n "$value" && -n "$validator" ]]; then
        # Special case: validate_choice needs options as second argument
        if [[ "$validator" == "validate_choice" ]]; then
            local options=$(field_get "$module" "$field" "options")
            if ! $validator "$value" "$options"; then
                validation_error "Invalid $display: $value (valid options: $options)"
                return 1
            fi
        else
            # Standard validator - error message comes from validator
            if ! $validator "$value"; then
                validation_error "Invalid $display: $value"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Prompt for one field (uses inputHelpers.sh functions)
# Usage: field_prompt "module" "field"
field_prompt() {
    local module="$1"
    local field="$2"
    
    local current=$(config_get "$module" "$field")
    local validator=$(field_get "$module" "$field" "validator")
    local required=$(field_get "$module" "$field" "required")
    local type=$(field_get "$module" "$field" "type")
    local display=$(field_get "$module" "$field" "display")
    local options=$(field_get "$module" "$field" "options")
    
    local req_flag="optional"
    [[ "$required" == "true" ]] && req_flag="required"
    
    # Auto-detect validator based on type if not specified
    if [[ -z "$validator" ]]; then
        case "$type" in
            choice) validator="validate_choice" ;;
            number) validator="validate_port" ;;  # Default number validator
            bool) validator="validate_yes_no" ;;
        esac
    fi
    
    local new_value
    
    # Use appropriate prompt from inputHelpers.sh based on type
    case "$type" in
        choice)
            new_value=$(prompt_choice "$display" "$current" "$options")
            ;;
        bool)
            new_value=$(prompt_bool "$display" "$current")
            ;;
        *)
            # Default: validated text input (works for text and number types)
            # Validators handle their own constraints (no need for min/max)
            new_value=$(prompt_validated "$display" "$current" "$validator" "$req_flag")
            ;;
    esac
    
    # Update if changed
    if [[ "$new_value" != "$current" ]]; then
        config_set "$module" "$field" "$new_value"
        console "    -> Updated: $field = $new_value"
    fi
}

# =============================================================================
# MODULE-LEVEL OPERATIONS
# =============================================================================

# Validate all active fields in a module
# Usage: module_validate "module"
module_validate() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    local validation_errors=0
    
    # Check if get_active_fields function exists
    if ! type "$get_fields" &>/dev/null; then
        error "Module $module must implement ${get_fields}()"
        return 1
    fi
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Validate each active field
    for field in $($get_fields); do
        if ! field_validate "$module" "$field"; then
            ((validation_errors++))
        fi
    done
    
    # Call module's extra validation if exists (for cross-field validation)
    local extra_validate="${module}_validate_extra"
    if type "$extra_validate" &>/dev/null; then
        if ! $extra_validate; then
            ((validation_errors++))
        fi
    fi
    
    return "$validation_errors"
}

# Prompt only for fields that failed validation
# Usage: module_prompt_errors "module"
module_prompt_errors() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    
    console "$(echo ${module^} | tr '_' ' ') Configuration:"
    console ""
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Only prompt for fields that fail validation
    for field in $($get_fields); do
        if ! field_validate "$module" "$field"; then
            field_prompt "$module" "$field"
        fi
    done
    
    console ""
}

# Prompt for all active fields in a module (full interactive)
# Usage: module_prompt_all "module"
module_prompt_all() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    
    console "$(echo ${module^} | tr '_' ' ') Configuration:"
    console ""
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Prompt for all active fields
    for field in $($get_fields); do
        field_prompt "$module" "$field"
    done
    
    console ""
}

# Display module configuration
# Usage: module_display "module"
module_display() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    
    console "$(echo ${module^} | tr '_' ' ') Configuration:"
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Display each active field
    for field in $($get_fields); do
        local display=$(field_get "$module" "$field" "display")
        local value=$(config_get "$module" "$field")
        console "  $display: $value"
    done
}

# =============================================================================
# MODULE LOADING & INITIALIZATION
# =============================================================================

# Load and use a configuration module
# Usage: config_use_module "network"
config_use_module() {
    local module="$1"
    local module_file
    
    # Try to find module file
    if [[ -f "${SCRIPT_DIR}/lib/setupConfiguration/${module}.sh" ]]; then
        module_file="${SCRIPT_DIR}/lib/setupConfiguration/${module}.sh"
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/setupConfiguration/${module}.sh" ]]; then
        module_file="$(dirname "${BASH_SOURCE[0]}")/setupConfiguration/${module}.sh"
    else
        error "Configuration module not found: $module"
        return 1
    fi
    
    # Source the module if not already loaded
    if [[ "${MODULE_REGISTRY[${module}__loaded]:-false}" != "true" ]]; then
        # shellcheck disable=SC1090
        source "$module_file"
        MODULE_REGISTRY["${module}__loaded"]="true"
        debug "Module loaded: $module"
    fi
    
    # Initialize the module
    config_init_module "$module"
}

# Initialize a module (called by config_use_module or directly)
# Usage: config_init_module "module"
config_init_module() {
    local module="$1"
    
    # Set module context
    MODULE_CONTEXT="$module"
    
    # Call module's init callback if it exists
    local init_callback="${module}_init_callback"
    if type "$init_callback" &>/dev/null; then
        $init_callback
    else
        # No init callback - that's okay for inline field declarations
        debug "No init callback for module: $module"
    fi
    
    # Apply DPS_* environment variable overrides
    config_apply_env_overrides "$module"
    
    success "Configuration initialized for module: $module"
}

# =============================================================================
# HIGH-LEVEL WORKFLOW
# =============================================================================

# Fix validation errors only (minimal prompting)
# Usage: config_fix_errors "module1" "module2" ...
config_fix_errors() {
    local modules=("$@")
    
    console ""
    warn "Some configuration values are missing or invalid."
    console "Please provide the required information:"
    console ""
    
    # Only prompt failed modules
    for module in "${modules[@]}"; do
        if ! module_validate "$module"; then
            module_prompt_errors "$module"
        fi
    done
}

# Interactive category selection menu
# Usage: config_menu "module1" "module2" ...
config_menu() {
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
            local display=$(echo ${module^} | tr '_' ' ')
            console "  $i) $display"
        done
        console ""
        
        # Show current configuration (no header)
        for module in "${modules[@]}"; do
            module_display "$module"
            console ""
        done
        
        # Get selection
        printf "Select category (0-$i): "
        read -r selection < /dev/tty
        
        if [[ "$selection" == "0" ]]; then
            # Validate before confirming
            local validation_errors=0
            for module in "${modules[@]}"; do
                if ! module_validate "$module"; then
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
            section_header "$(echo ${selected_module^} | tr '_' ' ') Configuration"
            console "Press ENTER to keep current value, or type new value"
            console ""
            module_prompt_all "$selected_module"
            success "$(echo ${selected_module^} | tr '_' ' ') configuration updated"
        else
            warn "Invalid selection. Please enter a number between 0 and $i."
        fi
    done
}

# Complete configuration workflow
# Usage: config_workflow "module1" "module2" ...
config_workflow() {
    local modules=("$@")
    
    # Validate all modules
    local validation_errors=0
    for module in "${modules[@]}"; do
        if ! module_validate "$module"; then
            ((validation_errors++))
        fi
    done
    
    # If validation fails, fix errors only
    if [[ "$validation_errors" -gt 0 ]]; then
        config_fix_errors "${modules[@]}"
        
        # Re-validate after fixes
        validation_errors=0
        for module in "${modules[@]}"; do
            if ! module_validate "$module"; then
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
        module_display "$module"
        console ""
    done
    
    # Ask if user wants to modify anything
    while true; do
        printf "Do you want to modify any settings? [y/n]: "
        read -r response < /dev/tty
        
        case "${response,,}" in
            y|yes)
                # Show interactive menu
                config_menu "${modules[@]}"
                
                # After menu, show updated config
                console ""
                section_header "Configuration Summary"
                for module in "${modules[@]}"; do
                    module_display "$module"
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
