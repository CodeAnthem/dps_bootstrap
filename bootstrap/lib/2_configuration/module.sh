#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Module Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-24
# Description:   Module-level validation, prompting, and display
# Dependencies:  2_field.sh
# ==================================================================================================

# =============================================================================
# MODULE VALIDATION
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

# =============================================================================
# MODULE PROMPTING
# =============================================================================

# Prompt only for fields that failed validation
# Usage: module_prompt_errors "module"
module_prompt_errors() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # First pass: check if there are any fields that need prompting
    local fields_to_prompt=()
    for field in $($get_fields); do
        if ! field_validate "$module" "$field" 2>/dev/null; then
            fields_to_prompt+=("$field")
        fi
    done
    
    # Only show header and prompt if there are fields that need input
    if [[ ${#fields_to_prompt[@]} -gt 0 ]]; then
        console "$(echo "${module^}" | tr '_' ' ') Configuration:"
        
        for field in "${fields_to_prompt[@]}"; do
            field_prompt "$module" "$field"
        done
        
        console ""
    fi
}

# Prompt for all active fields in a module (full interactive)
# Usage: module_prompt_all "module"
module_prompt_all() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    
    console "$(echo "${module^}" | tr '_' ' ') Configuration:"
    console ""
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Keep track of prompted fields to avoid re-prompting
    local -A prompted_fields
    
    # Loop until all active fields have been prompted
    while true; do
        local has_new_fields=false
        
        # Check for any active fields that haven't been prompted yet
        for field in $($get_fields); do
            if [[ -z "${prompted_fields[$field]:-}" ]]; then
                field_prompt "$module" "$field"
                prompted_fields["$field"]=1
                has_new_fields=true
            fi
        done
        
        # If no new fields appeared, we're done
        if [[ "$has_new_fields" == "false" ]]; then
            break
        fi
    done
    
    console ""
}

# =============================================================================
# MODULE DISPLAY
# =============================================================================

# Display module configuration
# Usage: module_display "module" [number]
module_display() {
    local module="$1"
    local number="${2:-}"
    local get_fields="${module}_get_active_fields"
    
    local header="$(echo "${module^}" | tr '_' ' ') Configuration:"
    if [[ -n "$number" ]]; then
        console "$number. $header"
    else
        console "$header"
    fi
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Display each active field
    for field in $($get_fields); do
        local display
        local value
        display=$(field_get "$module" "$field" "display")
        value=$(config_get "$module" "$field")
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
    
    # Try to find module file in new location first, then old location
    if [[ -f "$LIB_ROOT/2_configuration/modules/${module}.sh" ]]; then
        module_file="$LIB_ROOT/2_configuration/modules/${module}.sh"
    elif [[ -f "${SCRIPT_DIR}/lib/setupConfiguration/${module}.sh" ]]; then
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
    
    debug "Configuration initialized for module: $module"
}
