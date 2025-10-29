#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Category Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-29
# Description:   Category-level validation, prompting, and display (internal operations)
# Dependencies:  field.sh
# ==================================================================================================

# =============================================================================
# CATEGORY VALIDATION
# =============================================================================

# Get active fields for a category (auto-generates if get_active_fields doesn't exist)
# Usage: _nds_category_get_fields "category"
# Note: ${category}_get_active_fields() is OPTIONAL. Only implement it if you need
#       conditional field activation (e.g., network category shows IP fields only for static).
#       If not implemented, all declared fields are automatically returned.
_nds_category_get_fields() {
    local category="$1"
    local get_fields="${category}_get_active_fields"
    
    # If category has get_active_fields function, use it (for conditional fields)
    if type "$get_fields" &>/dev/null; then
        $get_fields
        return 0
    fi
    
    # Otherwise, auto-generate from all declared fields (default behavior)
    for key in "${!FIELD_REGISTRY[@]}"; do
        if [[ "$key" =~ ^${category}__(.+)__display$ ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done
}

# Validate all active fields in a category
# Usage: _nds_category_validate "category"
_nds_category_validate() {
    local category="$1"
    local validation_errors=0
    
    # Set category context for get_active_fields to work
    MODULE_CONTEXT="$category"
    
    # Validate each active field
    for field in $(_nds_category_get_fields "$category"); do
        if ! _nds_field_validate "$category" "$field"; then
            ((validation_errors++))
        fi
    done
    
    # Call category's extra validation if exists (for cross-field validation)
    local extra_validate="${category}_validate_extra"
    if type "$extra_validate" &>/dev/null; then
        if ! $extra_validate; then
            ((validation_errors++))
        fi
    fi
    
    return "$validation_errors"
}

# =============================================================================
# CATEGORY PROMPTING
# =============================================================================

# Prompt only for fields that failed validation
# Usage: _nds_category_prompt_errors "category"
_nds_category_prompt_errors() {
    local category="$1"
    
    # Set category context for get_active_fields to work
    MODULE_CONTEXT="$category"
    
    # First pass: check if there are any fields that need prompting
    local fields_to_prompt=()
    for field in $(_nds_category_get_fields "$category"); do
        if ! _nds_field_validate "$category" "$field" 2>/dev/null; then
            fields_to_prompt+=("$field")
        fi
    done
    
    # Only show header and prompt if there are fields that need input
    if [[ ${#fields_to_prompt[@]} -gt 0 ]]; then
        console "$(echo "${category^}" | tr '_' ' ') Configuration:"
        
        for field in "${fields_to_prompt[@]}"; do
            _nds_field_prompt "$category" "$field"
        done
        
        console ""
    fi
}

# Prompt for all active fields in a category (full interactive)
# Usage: _nds_category_prompt_all "category"
_nds_category_prompt_all() {
    local category="$1"
    
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

# =============================================================================
# MODULE INTEGRITY VALIDATION
# =============================================================================

# Check if a module has all required functions
# Usage: nds_module_check_integrity "module"
# Returns: 0 if valid, 1 if missing required functions
nds_module_check_integrity() {
    local module="$1"
    local missing=0
    
    # Required function: init_callback
    if ! type "${module}_init_callback" &>/dev/null; then
        warn "Module '$module': Missing required function ${module}_init_callback()"
        ((missing++))
    fi
    
    # Required function: nds_nixcfg_<module>_auto (for NixOS config generation)
    if ! type "nds_nixcfg_${module}_auto" &>/dev/null; then
        warn "Module '$module': Missing required function nds_nixcfg_${module}_auto()"
        ((missing++))
    fi
    
    # Required function: nds_nixcfg_<module> (manual mode)
    if ! type "nds_nixcfg_${module}" &>/dev/null; then
        warn "Module '$module': Missing required function nds_nixcfg_${module}()"
        ((missing++))
    fi
    
    # Optional functions (no warning if missing):
    # - ${module}_get_active_fields() - for conditional field display
    # - ${module}_validate_extra() - for cross-field validation
    
    return $missing
}

# Check integrity of multiple modules
# Usage: nds_module_check_all_integrity "module1" "module2" ...
# Returns: 0 if all valid, 1 if any missing required functions
nds_module_check_all_integrity() {
    local modules=("$@")
    local failed=0
    
    for module in "${modules[@]}"; do
        if ! nds_module_check_integrity "$module"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        error "$failed module(s) failed integrity check"
        return 1
    fi
    
    success "All modules passed integrity check"
    return 0
}
