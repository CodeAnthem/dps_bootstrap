#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configurator - ConfigVar Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-30
# Description:   ConfigVar validation and prompting
# Dependencies:  storage.sh, inputs/**
# ==================================================================================================

# ----------------------------------------------------------------------------------
# CONFIGVAR VALIDATION
# ----------------------------------------------------------------------------------

nds_configurator_var_validate() {
    local varname="$1"
    local value
    local required
    local input
    local display
    
    value=$(nds_cfg_get "$varname")
    required=$(nds_configurator_var_get_meta "$varname" "required")
    input=$(nds_configurator_var_get_meta "$varname" "input")
    display=$(nds_configurator_var_get_meta "$varname" "display")
    
    # Check required
    if [[ "$required" == "true" && -z "$value" ]]; then
        validation_error "$display is required"
        return 1
    fi
    
    # Skip if empty and optional
    [[ -z "$value" ]] && return 0
    
    # Set context and validate
    _nds_configurator_set_validator_context "$varname"
    
    local error_code
    "validate_${input}" "$value"
    error_code=$?
    
    _nds_configurator_clear_validator_context
    
    if [[ "$error_code" -ne 0 ]]; then
        local error_msg
        error_msg=$(nds_configurator_var_get_meta "$varname" "error")
        
        if [[ -z "$error_msg" ]] && type "error_msg_${input}" &>/dev/null; then
            error_msg=$("error_msg_${input}" "$value" "$error_code")
        fi
        
        validation_error "${error_msg:-Invalid $display}"
        return 1
    fi
    
    return 0
}

# ----------------------------------------------------------------------------------
# PROMPTING
# ----------------------------------------------------------------------------------

_nds_configurator_prompt_generic() {
    local display="$1"
    local current="$2"
    local input="$3"
    
    local hint=""
    type "prompt_hint_${input}" &>/dev/null && hint=$("prompt_hint_${input}")
    
    local read_type
    read_type=$(_nds_configurator_get_validator_opt "read_type" "string")
    
    while true; do
        if [[ -n "$hint" ]]; then
            printf "  %-20s [%s] %s: " "$display" "$current" "$hint" >&2
        else
            printf "  %-20s [%s]: " "$display" "$current" >&2
        fi
        
        local value
        if [[ "$read_type" == "char" ]]; then
            read -r -n 1 value < /dev/tty
            echo >&2
        else
            read -r value < /dev/tty
        fi
        
        [[ -z "$value" ]] && echo "$current" && return 0
        
        if "validate_${input}" "$value" 2>/dev/null; then
            type "normalize_${input}" &>/dev/null && value=$("normalize_${input}" "$value")
            echo "$value"
            return 0
        fi
        
        local error="Invalid input"
        type "error_msg_${input}" &>/dev/null && error=$("error_msg_${input}" "$value")
        console "    Error: $error"
    done
}

nds_configurator_var_prompt() {
    local varname="$1"
    local input
    local display
    local current
    local required
    
    input=$(nds_configurator_var_get_meta "$varname" "input")
    display=$(nds_configurator_var_get_meta "$varname" "display")
    current=$(nds_cfg_get "$varname")
    required=$(nds_configurator_var_get_meta "$varname" "required")
    
    while true; do
        _nds_configurator_set_validator_context "$varname"
        
        local new_value
        if type "prompt_${input}" &>/dev/null; then
            new_value=$("prompt_${input}" "$display" "$current")
        else
            new_value=$(_nds_configurator_prompt_generic "$display" "$current" "$input")
        fi
        
        _nds_configurator_clear_validator_context
        
        # Empty = keep current
        if [[ -z "$new_value" ]]; then
            if [[ "$required" == "true" && -z "$current" ]]; then
                validation_error "$display is required"
                continue
            fi
            return 0
        fi
        
        # Update value
        nds_cfg_set "$varname" "$new_value"
        
        if [[ "$current" != "$new_value" ]]; then
            if [[ -n "$current" ]]; then
                console "    -> Updated: $current -> $new_value"
            else
                console "    -> Set: $new_value"
            fi
        fi
        
        # Special hook for COUNTRY field
        if [[ "$varname" == "COUNTRY" && -n "$new_value" ]]; then
            if type apply_country_defaults &>/dev/null; then
                apply_country_defaults "$new_value" && console "    -> Applied country defaults"
            fi
        fi
        
        return 0
    done
}
