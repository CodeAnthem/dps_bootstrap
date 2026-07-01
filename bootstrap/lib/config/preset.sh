#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configurator - ConfigPreset Operations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2026-06-30
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
    local display header_shown=false

    display=$(nds_configurator_preset_get_display "$preset")
    [[ "$display" != *"Configuration"* ]] && display="${display} Configuration"

    # Re-evaluate active fields after each prompt (same as prompt_all).
    declare -A _nds_prompted=()
    while true; do
        local varname prompted_any=false
        for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
            [[ -n "${_nds_prompted[$varname]:-}" ]] && continue
            if ! nds_configurator_var_validate "$varname" 2>/dev/null; then
                if [[ "$header_shown" != true ]]; then
                    nds_ui_h "${display}:"
                    header_shown=true
                fi
                nds_configurator_var_prompt "$varname"
                _nds_prompted[$varname]=1
                prompted_any=true
                break
            fi
            _nds_prompted[$varname]=1
        done
        [[ "$prompted_any" == false ]] && break
    done

    [[ "$header_shown" == true ]] && nds_ui_b ""
}

nds_configurator_preset_prompt_all() {
    local preset="$1"

    local display
    display=$(nds_configurator_preset_get_display "$preset")
    [[ "$display" != *"Configuration"* ]] && display="${display} Configuration"
    nds_ui_h "${display}:"
    nds_ui_b ""

    # Re-evaluate active fields after every prompt so toggles (e.g. remote unlock,
    # encryption on/off) immediately surface dependent questions in the same pass.
    declare -A _nds_prompted=()
    while true; do
        local varname prompted_any=false
        for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
            [[ -n "${_nds_prompted[$varname]:-}" ]] && continue
            nds_configurator_var_prompt "$varname"
            _nds_prompted[$varname]=1
            prompted_any=true
            break
        done
        [[ "$prompted_any" == false ]] && break
    done
}

# =============================================================================
# DISPLAY
# =============================================================================

nds_configurator_preset_display() {
    local preset="$1"
    local number="${2:-}"
    
    local header display
    display=$(nds_configurator_preset_get_display "$preset")
    # Only add Configuration suffix if display name doesn't already contain it
    [[ "$display" != *"Configuration"* ]] && display="${display} Configuration"
    header="${display}:"
    [[ -n "$number" ]] && header="$number. $header"
    nds_ui_h "$header"
    
    for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
        local display
        local value
        local input
        
        display=$(nds_configurator_var_get_meta "$varname" "display")
        value=$(nds_configurator_config_get "$varname")
        input=$(nds_configurator_var_get_meta "$varname" "input")
        
        # Transform for display if function exists (choice labels need validator context)
        _nds_configurator_set_validator_context "$varname"
        if type "display_${input}" &>/dev/null; then
            value=$("display_${input}" "$value")
        fi
        _nds_configurator_clear_validator_context

        nds_ui_kv_row "$display" "$value"
    done
}

