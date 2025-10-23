#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - String
# Feature:       Alphanumeric string validation with optional length constraints
# ==================================================================================================

# =============================================================================
# STRING INPUT
# =============================================================================

prompt_hint_string() {
    local minlen=$(input_opt "minlen" "")
    local maxlen=$(input_opt "maxlen" "")
    
    if [[ -n "$minlen" && -n "$maxlen" ]]; then
        echo "(length: $minlen-$maxlen chars)"
    elif [[ -n "$minlen" ]]; then
        echo "(min: $minlen chars)"
    elif [[ -n "$maxlen" ]]; then
        echo "(max: $maxlen chars)"
    fi
}

validate_string() {
    local value="$1"
    local minlen=$(input_opt "minlen" "")
    local maxlen=$(input_opt "maxlen" "")
    local pattern=$(input_opt "pattern" "")
    
    # Check pattern if specified
    if [[ -n "$pattern" ]]; then
        [[ "$value" =~ $pattern ]] || return 1
    fi
    
    # Check length if specified
    local len=${#value}
    [[ -n "$minlen" && "$len" -lt "$minlen" ]] && return 1
    [[ -n "$maxlen" && "$len" -gt "$maxlen" ]] && return 1
    
    return 0
}

error_msg_string() {
    local minlen=$(input_opt "minlen" "")
    local maxlen=$(input_opt "maxlen" "")
    local pattern=$(input_opt "pattern" "")
    
    if [[ -n "$pattern" ]]; then
        echo "Must match pattern: $pattern"
    elif [[ -n "$minlen" && -n "$maxlen" ]]; then
        echo "Length must be between $minlen and $maxlen characters"
    elif [[ -n "$minlen" ]]; then
        echo "Must be at least $minlen characters"
    elif [[ -n "$maxlen" ]]; then
        echo "Must be at most $maxlen characters"
    else
        echo "Invalid string"
    fi
}
