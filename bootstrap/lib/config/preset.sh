#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configurator - ConfigPreset Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-30
# Description:   ConfigPreset validation, prompting, and display
# Dependencies:  storage.sh, var.sh
# ==================================================================================================

# =============================================================================
# VAR QUERIES
# =============================================================================

nds_configurator_preset_get_vars() {
    local preset="$1"
    nds_configurator_var_list "$preset"
}

nds_configurator_preset_get_active_vars() {
    local preset="$1"
    
    # Use cached function check
    if _nds_configurator_preset_has_function "$preset" "get_active"; then
        PRESET_CONTEXT="$preset"
        "${preset}_get_active"
        PRESET_CONTEXT=""
    else
        nds_configurator_preset_get_vars "$preset"
    fi
}

# =============================================================================
# VALIDATION
# =============================================================================

nds_configurator_preset_validate() {
    local preset="$1"
    local errors=0
    
    for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
        nds_configurator_var_validate "$varname" 2>/dev/null || ((errors++))
    done
    
    # Use cached function check for extra validation
    if _nds_configurator_preset_has_function "$preset" "validate_extra"; then
        "${preset}_validate_extra" || ((errors++))
    fi
    
    return $errors
}

nds_configurator_preset_validate_all() {
    local errors=0
    for preset in "$@"; do
        nds_configurator_preset_validate "$preset" 2>/dev/null || ((errors++))
    done
    return $errors
}

# =============================================================================
# PROMPTING
# =============================================================================

nds_configurator_preset_prompt_errors() {
    local preset="$1"
    local vars_to_prompt=()
    
    for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
        nds_configurator_var_validate "$varname" 2>/dev/null || vars_to_prompt+=("$varname")
    done
    
    if [[ ${#vars_to_prompt[@]} -gt 0 ]]; then
        console "$(nds_configurator_preset_get_display "$preset") Configuration:"
        for varname in "${vars_to_prompt[@]}"; do
            nds_configurator_var_prompt "$varname"
        done
        console ""
    fi
}

nds_configurator_preset_prompt_all() {
    local preset="$1"
    
    console "$(nds_configurator_preset_get_display "$preset") Configuration:"
    console ""
    
    for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
        nds_configurator_var_prompt "$varname"
    done
}

# =============================================================================
# DISPLAY
# =============================================================================

nds_configurator_preset_display() {
    local preset="$1"
    local number="${2:-}"
    
    local header
    header="$(nds_configurator_preset_get_display "$preset") Configuration:"
    [[ -n "$number" ]] && header="$number. $header"
    console "$header"
    
    for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
        local display
        local value
        local input
        
        display=$(nds_configurator_var_get_meta "$varname" "display")
        value=$(nds_configurator_config_get "$varname")
        input=$(nds_configurator_var_get_meta "$varname" "input")
        
        # Transform for display if function exists
        type "display_${input}" &>/dev/null && value=$("display_${input}" "$value")
        
        console "   > $display: $value"
    done
}

