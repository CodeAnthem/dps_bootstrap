#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS Configuration System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Description:   Generic configuration system with field-based metadata
# Architecture:  Module declares fields → Generic validation/prompting → Smart workflow
# ==================================================================================================
# shellcheck disable=SC2155

# =============================================================================
# GLOBAL STATE
# =============================================================================
# Current module context (set during init) - exported for subshells
declare -gx MODULE_CONTEXT=""

# Field metadata registry: module__field__attribute → value
declare -gA FIELD_REGISTRY 2>/dev/null || true

# Configuration data storage: module__field → value
declare -gA CONFIG_DATA 2>/dev/null || true

# Module registry: stores module callbacks
declare -gA MODULE_REGISTRY 2>/dev/null || true

# Input context (set during field_prompt/field_validate)
declare -gx INPUT_CONTEXT_MODULE=""
declare -gx INPUT_CONTEXT_FIELD=""

# Cached options for current input (populated when context is set)
declare -gA INPUT_OPTIONS_CACHE 2>/dev/null || true

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
    
    local input=$(field_get "$module" "$field" "input")
    local value=$(config_get "$module" "$field")
    local required=$(field_get "$module" "$field" "required")
    local display=$(field_get "$module" "$field" "display")
    
    # Check if required and empty
    if [[ "$required" == "true" && -z "$value" ]]; then
        validation_error "$display is required"
        return 1
    fi
    
    # Skip validation if empty and optional
    [[ -z "$value" ]] && return 0
    
    # Set context for validator
    set_input_context "$module" "$field"
    
    # Run validator
    local result=0
    if ! "validate_${input}" "$value"; then
        # Get custom error or use error_msg_* function if exists
        local error_msg=$(field_get "$module" "$field" "error")
        if [[ -z "$error_msg" ]] && type "error_msg_${input}" &>/dev/null; then
            error_msg=$("error_msg_${input}" "$value")
        fi
        validation_error "${error_msg:-Invalid $display}"
        result=1
    fi
    
    # Clear context
    clear_input_context
    
    return $result
}

# =============================================================================
# INPUT CONTEXT HELPERS
# =============================================================================

# Get option for current input with default fallback
# Usage: input_opt "option_name" "default_value"
input_opt() {
    local option="$1"
    local default="${2:-}"
    echo "${INPUT_OPTIONS_CACHE[$option]:-$default}"
}

# Set input context and cache all options
set_input_context() {
    local module="$1"
    local field="$2"
    
    INPUT_CONTEXT_MODULE="$module"
    INPUT_CONTEXT_FIELD="$field"
    
    # Clear and populate options cache
    INPUT_OPTIONS_CACHE=()
    
    # Cache common options that inputs might need
    local opt
    for opt in min max minlen maxlen pattern options default required read_type error; do
        local value=$(field_get "$module" "$field" "$opt")
        [[ -n "$value" ]] && INPUT_OPTIONS_CACHE[$opt]="$value"
    done
}

# Clear input context
clear_input_context() {
    INPUT_CONTEXT_MODULE=""
    INPUT_CONTEXT_FIELD=""
    INPUT_OPTIONS_CACHE=()
}

# =============================================================================
# GENERIC INPUT LOOP
# =============================================================================

# Generic input loop - handles read, empty, validation, normalization
generic_input_loop() {
    local display="$1"
    local current="$2"
    local input_name="$3"
    
    # Get prompt hint if exists
    local hint=""
    if type "prompt_hint_${input_name}" &>/dev/null; then
        hint=$("prompt_hint_${input_name}")
    fi
    
    # Get read type (default: string with enter)
    local read_type=$(input_opt "read_type" "string")
    
    while true; do
        # Display prompt
        if [[ -n "$hint" ]]; then
            printf "  %-20s [%s] %s: " "$display" "$current" "$hint" >&2
        else
            printf "  %-20s [%s]: " "$display" "$current" >&2
        fi
        
        # Read based on type
        local value
        if [[ "$read_type" == "char" ]]; then
            read -r -n 1 value < /dev/tty
            echo >&2  # Newline after single char
        else
            read -r value < /dev/tty
        fi
        
        # Empty handling - keep current
        if [[ -z "$value" ]]; then
            # echo "$current"
            return 0
        fi
        
        # Validate
        if "validate_${input_name}" "$value"; then
            # Normalize if function exists
            if type "normalize_${input_name}" &>/dev/null; then
                value=$("normalize_${input_name}" "$value")
            fi
            echo "$value"
            return 0
        else
            # Get error message
            local error
            if type "error_msg_${input_name}" &>/dev/null; then
                error=$("error_msg_${input_name}" "$value")
            else
                error="Invalid input"
            fi
            console "    Error: $error"
        fi
    done
}

# =============================================================================
# FIELD PROMPTING
# =============================================================================

# Prompt user for a single field (with validation loop)
# Usage: field_prompt "module" "field"
field_prompt() {
    local module="$1"
    local field="$2"
    
    local input=$(field_get "$module" "$field" "input")
    local display=$(field_get "$module" "$field" "display")
    local current=$(config_get "$module" "$field")
    local required=$(field_get "$module" "$field" "required")
    
    # Loop until we get valid input or user provides valid current value
    while true; do
        # Set context and cache options
        set_input_context "$module" "$field"
        
        local new_value
        
        # Check if input has custom prompt
        if type "prompt_${input}" &>/dev/null; then
            # Use custom prompt
            new_value=$("prompt_${input}" "$display" "$current")
        else
            # Use generic loop
            new_value=$(generic_input_loop "$display" "$current" "$input")
        fi
        
        # Clear context
        clear_input_context
        
        # Empty input means keep current value
        if [[ -z "$new_value" ]]; then
            # Check if current value is valid
            if [[ "$required" == "true" && -z "$current" ]]; then
                validation_error "$display is required"
                continue  # Re-prompt
            fi
            
            # Validate current value
            if [[ -n "$current" ]]; then
                set_input_context "$module" "$field"
                if ! "validate_${input}" "$current"; then
                    # Get error message
                    local error_msg=$(field_get "$module" "$field" "error")
                    if [[ -z "$error_msg" ]] && type "error_msg_${input}" &>/dev/null; then
                        error_msg=$("error_msg_${input}" "$current")
                    fi
                    validation_error "${error_msg:-Invalid $display}"
                    clear_input_context
                    continue  # Re-prompt
                fi
                clear_input_context
            fi
            
            # Current value is valid, keep it
            return 0
        fi
        
        # New value provided - update
        config_set "$module" "$field" "$new_value"
        if [[ -n "$current" ]]; then
            console "    -> Updated: $current -> $new_value"
        else
            console "    -> Set: $new_value"
        fi
        
        return 0
    done
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

# Display module configuration
# Usage: module_display "module" [number]
module_display() {
    local module="$1"
    local number="$2"
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
    
    debug "Configuration initialized for module: $module"
}

# =============================================================================
# HIGH-LEVEL WORKFLOW
# =============================================================================

# Fix validation errors only (minimal prompting)
# Usage: config_fix_errors "module1" "module2" ...
config_fix_errors() {
    local modules=("$@")
    section_header "Configuration Required"
    
    # Prompt for missing/invalid fields in each module
    for module in "${modules[@]}"; do
        module_prompt_errors "$module"
    done
}

# Interactive category selection menu
# Usage: config_menu "module1" "module2" ...
config_menu() {
    local modules=("$@")
    
    while true; do
        section_header "Configuration Menu"
               
        # Show current configuration with numbers
        local i=0
        for module in "${modules[@]}"; do
        echo "i: $i"
            ((++i))
        echo "i: $i"
            module_display "$module" "$i"
            console ""
        done
        
        # Build menu
        console "Select category (1-$i or X to proceed):"
        echo -n "> "
        read -r -n 1 selection < /dev/tty
        echo  # Newline after single-char input
        
        if [[ "${selection,,}" == "x" ]]; then
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
            section_header "$(echo "${selected_module^}" | tr '_' ' ') Configuration"
            console "Press ENTER to keep current value, or type new value"
            console ""
            module_prompt_all "$selected_module"
            success "$(echo "${selected_module^}" | tr '_' ' ') configuration updated"
        else
            warn "Invalid selection. Please enter 1-$i or X to proceed."
        fi
    done
}

# Complete configuration workflow
# Usage: config_workflow "module1" "module2" ...
config_workflow() {
    local modules=("$@")
    
    # Check if any fields are missing (silent check)
    local needs_input=false
    for module in "${modules[@]}"; do
        if ! module_validate "$module" 2>/dev/null; then
            needs_input=true
            break
        fi
    done
    
    # If validation fails, prompt for required fields
    if [[ "$needs_input" == "true" ]]; then
        config_fix_errors "${modules[@]}"
        
        # Re-validate after input
        local validation_errors=0
        for module in "${modules[@]}"; do
            if ! module_validate "$module"; then
                ((validation_errors++))
            fi
        done
        
        if [[ "$validation_errors" -gt 0 ]]; then
            error "Configuration validation still has $validation_errors error(s)"
            return 1
        fi
        
        success "Configuration completed"
    fi
    
    # Display all configurations
    section_header "Configuration Summary"
    for module in "${modules[@]}"; do
        module_display "$module"
        console ""
    done
    
    # Ask if user wants to modify anything
    while true; do
        read -rsn 1 -p "-> Do you want to modify any settings? [y/n]: " response < /dev/tty
        
        case "${response,,}" in
            y|yes)
                # Show interactive menu
                console "Yes"
                config_menu "${modules[@]}"
                
                # After menu, show updated config0
                console ""
                section_header "Configuration Summary"
                for module in "${modules[@]}"; do
                    module_display "$module"
                    console ""
                done
                ;;
            n|no)
                console "No"
                success "Configuration confirmed"
                return 0
                ;;
            "") ;;
            *)
                console "Invalid input - Please enter 'y' or 'n'"
                ;;
        esac
    done
}
