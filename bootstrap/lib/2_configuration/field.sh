#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Field Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-24
# Description:   Field-level validation and prompting
# Dependencies:  1_core.sh, 1_inputs/**
# ==================================================================================================

# =============================================================================
# FIELD VALIDATION
# =============================================================================

# Validate one field
# Usage: field_validate "module" "field"
field_validate() {
    local module="$1"
    local field="$2"
    
    local input
    local value
    local required
    local display
    
    input=$(field_get "$module" "$field" "input")
    value=$(config_get "$module" "$field")
    required=$(field_get "$module" "$field" "required")
    display=$(field_get "$module" "$field" "display")
    
    # Check if required and empty
    if [[ "$required" == "true" && -z "$value" ]]; then
        validation_error "$display is required"
        return 1
    fi
    
    # Skip validation if empty and optional
    [[ -z "$value" ]] && return 0
    
    # Set context for validator
    set_input_context "$module" "$field"
    
    # Run validator and capture error code
    local error_code
    "validate_${input}" "$value"
    error_code=$?
    
    if [[ $error_code -ne 0 ]]; then
        # Get custom error or use error_msg_* function with error code
        local error_msg
        error_msg=$(field_get "$module" "$field" "error")
        if [[ -z "$error_msg" ]] && type "error_msg_${input}" &>/dev/null; then
            error_msg=$("error_msg_${input}" "$value" "$error_code")
        fi
        validation_error "${error_msg:-Invalid $display}"
        clear_input_context
        return 1
    fi
    
    # Clear context
    clear_input_context
    
    return 0
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
    local read_type
    read_type=$(input_opt "read_type" "string")
    
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
            return 0
        fi
        
        # Validate and capture error code
        local error_code
        "validate_${input_name}" "$value"
        error_code=$?
        
        if [[ $error_code -eq 0 ]]; then
            # Normalize if function exists
            if type "normalize_${input_name}" &>/dev/null; then
                value=$("normalize_${input_name}" "$value")
            fi
            echo "$value"
            return 0
        else
            # Get error message with error code
            local error
            if type "error_msg_${input_name}" &>/dev/null; then
                error=$("error_msg_${input_name}" "$value" "$error_code")
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
    
    local input
    local display
    local current
    local required
    
    input=$(field_get "$module" "$field" "input")
    display=$(field_get "$module" "$field" "display")
    current=$(config_get "$module" "$field")
    required=$(field_get "$module" "$field" "required")
    
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
                    local error_msg
                    error_msg=$(field_get "$module" "$field" "error")
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
