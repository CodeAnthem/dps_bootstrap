#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Module Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-27
# Description:   Module-level validation, prompting, and display
# Dependencies:  2_field.sh
# ==================================================================================================

# =============================================================================
# MODULE VALIDATION
# =============================================================================

# Get active fields for a module (auto-generates if get_active_fields doesn't exist)
# Usage: nds_module_get_fields "module"
# Note: ${module}_get_active_fields() is OPTIONAL. Only implement it if you need
#       conditional field activation (e.g., network module shows IP fields only for static).
#       If not implemented, all declared fields are automatically returned.
nds_module_get_fields() {
    local module="$1"
    local get_fields="${module}_get_active_fields"
    
    # If module has get_active_fields function, use it (for conditional fields)
    if type "$get_fields" &>/dev/null; then
        $get_fields
        return 0
    fi
    
    # Otherwise, auto-generate from all declared fields (default behavior)
    for key in "${!FIELD_REGISTRY[@]}"; do
        if [[ "$key" =~ ^${module}__(.+)__display$ ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done
}

# Validate all active fields in a module
# Usage: nds_module_validate "module"
nds_module_validate() {
    local module="$1"
    local validation_errors=0
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Validate each active field
    for field in $(nds_module_get_fields "$module"); do
        if ! nds_field_validate "$module" "$field"; then
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
# Usage: nds_module_prompt_errors "module"
nds_module_prompt_errors() {
    local module="$1"
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # First pass: check if there are any fields that need prompting
    local fields_to_prompt=()
    for field in $(nds_module_get_fields "$module"); do
        if ! nds_field_validate "$module" "$field" 2>/dev/null; then
            fields_to_prompt+=("$field")
        fi
    done
    
    # Only show header and prompt if there are fields that need input
    if [[ ${#fields_to_prompt[@]} -gt 0 ]]; then
        console "$(echo "${module^}" | tr '_' ' ') Configuration:"
        
        for field in "${fields_to_prompt[@]}"; do
            nds_field_prompt "$module" "$field"
        done
        
        console ""
    fi
}

# Prompt for all active fields in a module (full interactive)
# Usage: nds_module_prompt_all "module"
nds_module_prompt_all() {
    local module="$1"
    
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
        for field in $(nds_module_get_fields "$module"); do
            if [[ -z "${prompted_fields[$field]:-}" ]]; then
                nds_field_prompt "$module" "$field"
                prompted_fields["$field"]=1
                has_new_fields=true
            fi
        done
        
        # If no new fields appeared, we're done
        if [[ "$has_new_fields" == "false" ]]; then
            break
        fi
    done
}

# =============================================================================
# MODULE DISPLAY
# =============================================================================

# Display module configuration
# Usage: nds_module_display "module" [number]
nds_module_display() {
    local module="$1"
    local number="${2:-}"
    
    local header
    header="$(echo "${module^}" | tr '_' ' ') Configuration:"
    if [[ -n "$number" ]]; then
        console "$number. $header"
    else
        console "$header"
    fi
    
    # Set module context for get_active_fields to work
    MODULE_CONTEXT="$module"
    
    # Display each active field
    for field in $(nds_module_get_fields "$module"); do
        local display
        local value
        local input
        display=$(nds_field_get "$module" "$field" "display")
        value=$(nds_config_get "$module" "$field")
        input=$(nds_field_get "$module" "$field" "input")
        
        # Transform value for display if display function exists
        if type "display_${input}" &>/dev/null; then
            value=$("display_${input}" "$value")
        fi
        
        console "   > $display: $value"
    done
}

# =============================================================================
# MODULE LOADING & INITIALIZATION
# =============================================================================

# Load and use a configuration module
# Usage: nds_config_use_module "network"
nds_config_use_module() {
    local module="$1"
    local module_file
    
    # Find module file in new unified modules directory
    if [[ -f "${LIB_DIR}/modules/${module}.sh" ]]; then
        module_file="${LIB_DIR}/modules/${module}.sh"
    elif [[ -f "${SCRIPT_DIR}/lib/modules/${module}.sh" ]]; then
        module_file="${SCRIPT_DIR}/lib/modules/${module}.sh"
    else
        error "Module not found: $module"
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
    nds_config_init_module "$module"
}

# Initialize a module (called by nds_config_use_module or directly)
# Usage: nds_config_init_module "module"
nds_config_init_module() {
    local module="$1"
    
    # Set module context (used by field_declare in init callback)
    # shellcheck disable=SC2034
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
    nds_config_apply_env_overrides "$module"
    
    debug "Configuration initialized for module: $module"
}
