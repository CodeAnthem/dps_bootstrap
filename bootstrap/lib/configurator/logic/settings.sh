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
    
    # Prevent duplicate declarations in different presets
    if ! $is_new; then
        local existing_preset="${CFG_SETTINGS["${varname}::preset"]:-}"
        if [[ -n "$preset" && -n "$existing_preset" && "$preset" != "$existing_preset" ]]; then
            error "Setting '$varname' already declared in preset '$existing_preset', cannot redeclare in preset '$preset'"
            return 1
        fi
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

# Helper: Get origin precedence score
# manual/prompt (3) > env (2) > auto (1) > default (0)
_nds_cfg_origin_score() {
    case "$1" in
        manual|prompt) echo 3 ;;
        env) echo 2 ;;
        auto) echo 1 ;;
        default|"") echo 0 ;;
    esac
}

# Apply a value to a setting (normalize, validate, store, apply hook)
# Usage: nds_cfg_apply_setting VARNAME VALUE [ORIGIN]
nds_cfg_apply_setting() {
    local var="$1"
    local value="$2"
    local origin="${3:-auto}"
    
    # Check if setting exists
    if ! nds_cfg_setting_exists "$var"; then
        error "Setting '$var' does not exist. Create it first with nds_cfg_setting_create"
        return 1
    fi
    
    # Reentrancy guard: prevent infinite apply loops (A→B→A)
    local apply_depth="${CFG_APPLY_STACK["$var"]:-0}"
    if (( apply_depth >= 1 )); then
        debug "Reentrant apply for $var (depth=$apply_depth) - skipping to prevent loop"
        return 0
    fi
    CFG_APPLY_STACK["$var"]=$((apply_depth + 1))
    
    # Origin precedence check: don't overwrite higher-precedence values
    local current_origin="${CFG_SETTINGS["${var}::origin"]:-default}"
    local new_score
    local cur_score
    new_score=$(_nds_cfg_origin_score "$origin")
    cur_score=$(_nds_cfg_origin_score "$current_origin")
    
    if (( cur_score > new_score )); then
        debug "Skipping update of $var: existing origin '$current_origin' (score $cur_score) has precedence over '$origin' (score $new_score)"
        CFG_APPLY_STACK["$var"]=$((apply_depth))
        return 0
    fi
    
    local type="${CFG_SETTINGS["${var}::type"]}"
    
    # Set validator context so validators can access attributes
    CFG_VALIDATOR_CONTEXT="$var"
    
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
        CFG_VALIDATOR_CONTEXT=""
        CFG_APPLY_STACK["$var"]=$((apply_depth))
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
    
    # Clear context and decrement apply stack
    CFG_VALIDATOR_CONTEXT=""
    CFG_APPLY_STACK["$var"]=$((apply_depth))
    
    return 0
}

# Get setting value
# Usage: nds_cfg_get VARNAME
nds_cfg_get() {
    local var="$1"
    
    # Return empty string if setting doesn't exist (silent failure for flexibility)
    if ! nds_cfg_setting_exists "$var"; then
        echo ""
        return 0
    fi
    
    echo "${CFG_SETTINGS["${var}::value"]:-}"
}

# Set setting value directly (no validation)
# Usage: nds_cfg_set VARNAME VALUE
nds_cfg_set() {
    nds_cfg_apply_setting "$1" "$2" "manual"
}
