#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Settings Public API
# Feature:       Setting creation, validation, and prompting
# ==================================================================================================

# =============================================================================
# SETTINGS CREATION
# =============================================================================

# Create or modify a setting
# Usage: nds_cfg_setting_create VARNAME [--flag value ...]
nds_cfg_setting_create() {
    local varname="$1"
    shift
    
    # Check if modifying existing setting
    local is_new=true
    if nds_cfg_setting_exists "$varname"; then
        is_new=false
    fi
    
    # Parse arguments
    local type="" display="" default="" preset="" exportable="true"
    local visible_all="" visible_any="" options=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                type="$2"
                shift 2
                ;;
            --display)
                display="$2"
                shift 2
                ;;
            --default)
                default="$2"
                shift 2
                ;;
            --preset)
                preset="$2"
                shift 2
                ;;
            --exportable)
                exportable="$2"
                shift 2
                ;;
            --visible_all)
                visible_all="$2"
                shift 2
                ;;
            --visible_any)
                visible_any="$2"
                shift 2
                ;;
            --options)
                options="$2"
                shift 2
                ;;
            --*)
                # Unknown flag - store as attribute
                local flag="${1#--}"
                local value="$2"
                CFG_SETTINGS["${varname}::attr::${flag}"]="$value"
                shift 2
                ;;
            *)
                error "Unknown argument to nds_cfg_setting_create: $1"
                return 1
                ;;
        esac
    done
    
    # Use context preset if not specified
    if [[ -z "$preset" ]]; then
        preset="$CFG_CONTEXT_PRESET"
    fi
    
    # Validate required fields for new settings
    if $is_new; then
        if [[ -z "$type" ]]; then
            error "Setting '$varname' missing required --type"
            return 1
        fi
        
        if [[ -z "$preset" ]]; then
            error "Setting '$varname' created outside preset context and no --preset specified"
            return 1
        fi
        
        # Check if settingType exists
        if ! nds_cfg_settingType_exists "$type"; then
            error "Setting '$varname' references unknown type '$type'"
            return 1
        fi
        
        # Add to master list
        CFG_ALL_SETTINGS+=("$varname")
    fi
    
    # Store metadata
    [[ -n "$type" ]] && CFG_SETTINGS["${varname}::type"]="$type"
    [[ -n "$preset" ]] && CFG_SETTINGS["${varname}::preset"]="$preset"
    [[ -n "$display" ]] && CFG_SETTINGS["${varname}::display"]="$display"
    [[ -n "$default" ]] && CFG_SETTINGS["${varname}::default"]="$default"
    CFG_SETTINGS["${varname}::exportable"]="$exportable"
    [[ -n "$visible_all" ]] && CFG_SETTINGS["${varname}::visible_all"]="$visible_all"
    [[ -n "$visible_any" ]] && CFG_SETTINGS["${varname}::visible_any"]="$visible_any"
    [[ -n "$options" ]] && CFG_SETTINGS["${varname}::attr::options"]="$options"
    
    # Initialize value to default if new
    if $is_new; then
        CFG_SETTINGS["${varname}::value"]="$default"
        CFG_SETTINGS["${varname}::origin"]="default"
    fi
    
    # Cache settingType hooks for performance
    local type_stored="${CFG_SETTINGS["${varname}::type"]}"
    for hook in validate errorCode normalize display prompt promptHint apply; do
        local func="${CFG_SETTINGTYPES["${type_stored}::${hook}"]:-}"
        if [[ -n "$func" ]]; then
            CFG_SETTINGS["${varname}::hook::${hook}"]="$func"
        fi
    done
    
    # Add to preset order if new
    if $is_new; then
        local current_order="${CFG_PRESETS["${preset}::order"]:-}"
        if [[ -z "$current_order" ]]; then
            CFG_PRESETS["${preset}::order"]="$varname"
        else
            CFG_PRESETS["${preset}::order"]="${current_order} ${varname}"
        fi
    fi
    
    return 0
}

# =============================================================================
# SETTINGS VALIDATION
# =============================================================================

# Validate a setting's current value
# Returns: 0 if valid, 1 if invalid
nds_cfg_setting_validate() {
    local varname="$1"
    
    local value="${CFG_SETTINGS["${varname}::value"]:-}"
    local validateFunc="${CFG_SETTINGS["${varname}::hook::validate"]:-}"
    
    if [[ -z "$validateFunc" ]]; then
        error "Setting '$varname' has no validate hook"
        return 1
    fi
    
    # Empty value handling (always valid for optional fields)
    if [[ -z "$value" ]]; then
        local required="${CFG_SETTINGS["${varname}::required"]:-false}"
        if [[ "$required" == "true" ]]; then
            return 1
        fi
        return 0
    fi
    
    # Execute validation
    "$validateFunc" "$value"
}

# =============================================================================
# SETTINGS VALUE OPERATIONS
# =============================================================================

# Apply a value to a setting (normalize, validate, store, apply hook)
# Usage: nds_cfg_apply_setting VARNAME VALUE [ORIGIN]
nds_cfg_apply_setting() {
    local var="$1"
    local value="$2"
    local origin="${3:-auto}"
    
    local type="${CFG_SETTINGS["${var}::type"]}"
    
    # Normalize
    local normalizeFunc="${CFG_SETTINGS["${var}::hook::normalize"]:-}"
    if [[ -n "$normalizeFunc" ]]; then
        value=$("$normalizeFunc" "$value")
    fi
    
    # Validate
    local validateFunc="${CFG_SETTINGS["${var}::hook::validate"]:-}"
    if ! "$validateFunc" "$value"; then
        local errorFunc="${CFG_SETTINGS["${var}::hook::errorCode"]:-}"
        if [[ -n "$errorFunc" ]]; then
            "$errorFunc" "$value" >&2
        else
            error "Invalid value for $var: $value" >&2
        fi
        return 1
    fi
    
    # Store
    CFG_SETTINGS["${var}::value"]="$value"
    CFG_SETTINGS["${var}::origin"]="$origin"
    
    # Apply hook (if defined)
    local applyFunc="${CFG_SETTINGS["${var}::hook::apply"]:-}"
    if [[ -n "$applyFunc" ]]; then
        "$applyFunc" "$value"
    fi
    
    return 0
}

# Get setting value
# Usage: nds_cfg_get VARNAME
nds_cfg_get() {
    echo "${CFG_SETTINGS["${1}::value"]:-}"
}

# Set setting value directly (no validation)
# Usage: nds_cfg_set VARNAME VALUE
nds_cfg_set() {
    nds_cfg_apply_setting "$1" "$2" "manual"
}
