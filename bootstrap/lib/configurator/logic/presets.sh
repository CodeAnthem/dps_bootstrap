#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Presets Public API
# Feature:       Preset creation, validation, and management
# ==================================================================================================

# =============================================================================
# PRESET CREATION
# =============================================================================

# Create a preset and set it as current context
# Usage: nds_cfg_preset_create "network" [--flag value ...]
nds_cfg_preset_create() {
    local preset="$1"
    shift
    
    # Check if preset already exists
    if nds_cfg_preset_exists "$preset"; then
        error "Preset '$preset' already exists"
        return 1
    fi
    
    # Parse arguments
    local display="" priority="50"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --display)
                display="$2"
                shift 2
                ;;
            --priority)
                priority="$2"
                shift 2
                ;;
            *)
                error "Unknown argument to nds_cfg_preset_create: $1"
                return 1
                ;;
        esac
    done
    
    # Default display to capitalized preset name
    if [[ -z "$display" ]]; then
        display="$(echo "${preset^}" | tr '_' ' ')"
    fi
    
    # Store preset metadata
    CFG_PRESETS["${preset}::display"]="$display"
    CFG_PRESETS["${preset}::priority"]="$priority"
    CFG_PRESETS["${preset}::order"]=""
    
    # Add to master list
    CFG_ALL_PRESETS+=("$preset")
    
    # Set as current context
    CFG_CONTEXT_PRESET="$preset"
    
    # Auto-detect validation function
    if declare -F "_${preset}_validate" &>/dev/null; then
        CFG_PRESETS["${preset}::hook::validate"]="_${preset}_validate"
    fi
    
    return 0
}

# =============================================================================
# PRESET VALIDATION
# =============================================================================

# Validate all settings in a preset
# Returns: 0 if all valid, error count if any invalid
nds_cfg_preset_validate() {
    local preset="$1"
    local errors=0
    
    # Validate each visible setting
    local order="${CFG_PRESETS["${preset}::order"]:-}"
    for varname in $order; do
        # Skip if not visible
        if ! nds_cfg_setting_isVisible "$varname"; then
            continue
        fi
        
        # Validate setting
        if ! nds_cfg_setting_validate "$varname"; then
            ((errors++))
        fi
    done
    
    # Run preset-level validation if defined
    local validateFunc="${CFG_PRESETS["${preset}::hook::validate"]:-}"
    if [[ -n "$validateFunc" ]]; then
        if ! "$validateFunc"; then
            ((errors++))
        fi
    fi
    
    return $errors
}

# Validate all presets
nds_cfg_preset_validate_all() {
    local errors=0
    
    for preset in "${CFG_ALL_PRESETS[@]}"; do
        debug "Validating preset: $preset"
        if ! nds_cfg_preset_validate "$preset"; then
            ((errors++))
        fi
    done
    
    return $errors
}

# =============================================================================
# PRESET QUERIES
# =============================================================================

# Get all settings in a preset
nds_cfg_preset_getSettings() {
    local preset="$1"
    echo "${CFG_PRESETS["${preset}::order"]:-}"
}

# Get all visible settings in a preset
nds_cfg_preset_getVisibleSettings() {
    local preset="$1"
    local order="${CFG_PRESETS["${preset}::order"]:-}"
    
    for varname in $order; do
        if nds_cfg_setting_isVisible "$varname"; then
            echo "$varname"
        fi
    done
}

# Get all presets sorted by priority
nds_cfg_preset_getAllSorted() {
    # Build array with priority:preset
    local sorted=()
    for preset in "${CFG_ALL_PRESETS[@]}"; do
        local priority="${CFG_PRESETS["${preset}::priority"]:-50}"
        sorted+=("${priority}:${preset}")
    done
    
    # Sort and extract preset names
    printf '%s\n' "${sorted[@]}" | sort -t: -k1,1n -k2,2 | cut -d: -f2
}

# =============================================================================
# PRESET DISPLAY
# =============================================================================

# Display preset settings
nds_cfg_preset_display() {
    local preset="$1"
    local number="${2:-}"
    
    local display="${CFG_PRESETS["${preset}::display"]}"
    local header="${display} Configuration:"
    [[ -n "$number" ]] && header="$number. $header"
    
    console "$header"
    
    local order="${CFG_PRESETS["${preset}::order"]:-}"
    for varname in $order; do
        # Skip if not visible
        if ! nds_cfg_setting_isVisible "$varname"; then
            continue
        fi
        
        local setting_display="${CFG_SETTINGS["${varname}::display"]}"
        local value="${CFG_SETTINGS["${varname}::value"]:-}"
        
        # Transform for display if function exists
        local displayFunc="${CFG_SETTINGS["${varname}::hook::display"]:-}"
        if [[ -n "$displayFunc" ]]; then
            value=$("$displayFunc" "$value")
        fi
        
        console "   > $setting_display: $value"
    done
}

# =============================================================================
# PRESET PROMPTING
# =============================================================================

# Prompt for all visible settings in preset
nds_cfg_preset_prompt_all() {
    local preset="$1"
    
    local display="${CFG_PRESETS["${preset}::display"]}"
    console "${display} Configuration:"
    console ""
    
    local order="${CFG_PRESETS["${preset}::order"]:-}"
    for varname in $order; do
        # Skip if not visible
        if ! nds_cfg_setting_isVisible "$varname"; then
            continue
        fi
        
        _nds_cfg_setting_prompt "$varname"
    done
}

# Prompt only for invalid settings in preset
nds_cfg_preset_prompt_errors() {
    local preset="$1"
    local vars_to_prompt=()
    
    local order="${CFG_PRESETS["${preset}::order"]:-}"
    for varname in $order; do
        # Skip if not visible
        if ! nds_cfg_setting_isVisible "$varname"; then
            continue
        fi
        
        # Check if valid
        if ! nds_cfg_setting_validate "$varname" 2>/dev/null; then
            vars_to_prompt+=("$varname")
        fi
    done
    
    if [[ ${#vars_to_prompt[@]} -gt 0 ]]; then
        local display="${CFG_PRESETS["${preset}::display"]}"
        console "${display} Configuration:"
        
        for varname in "${vars_to_prompt[@]}"; do
            # Re-check visibility (earlier prompts may have changed conditions)
            if ! nds_cfg_setting_isVisible "$varname"; then
                debug "Skipping $varname — not visible after previous changes"
                continue
            fi
            
            _nds_cfg_setting_prompt "$varname"
        done
        
        console ""
    fi
}

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

# Prompt for a single setting
_nds_cfg_setting_prompt() {
    local varname="$1"
    
    local type="${CFG_SETTINGS["${varname}::type"]}"
    local display="${CFG_SETTINGS["${varname}::display"]}"
    local current="${CFG_SETTINGS["${varname}::value"]:-}"
    
    while true; do
        # Get prompt function
        local promptFunc="${CFG_SETTINGS["${varname}::hook::prompt"]:-}"
        
        if [[ -z "$promptFunc" ]]; then
            error "Setting '$varname' has no prompt hook"
            return 1
        fi
        
        # Execute prompt
        local new_value
        new_value=$("$promptFunc" "$display" "$current" "$type")
        
        # Empty = keep current
        if [[ -z "$new_value" ]]; then
            return 0
        fi
        
        # Apply and validate
        if nds_cfg_apply_setting "$varname" "$new_value" "prompt"; then
            # Update successful
            if [[ "$current" != "$new_value" ]]; then
                if [[ -n "$current" ]]; then
                    console "    -> Updated: $current -> $new_value"
                else
                    console "    -> Set: $new_value"
                fi
            fi
            return 0
        else
            # Validation failed - loop and try again
            console "    Please try again."
        fi
    done
}
