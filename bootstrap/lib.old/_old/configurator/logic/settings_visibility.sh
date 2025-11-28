#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Visibility Logic
# Feature:       Dynamic visibility evaluation based on conditions
# ==================================================================================================

# ----------------------------------------------------------------------------------
# VISIBILITY EVALUATION
# ----------------------------------------------------------------------------------

# Check if a setting is visible based on its visibility conditions
# Returns: 0 if visible, 1 if hidden
nds_cfg_setting_isVisible() {
    local varname="$1"
    
    local visible_all="${CFG_SETTINGS["${varname}::visible_all"]:-}"
    local visible_any="${CFG_SETTINGS["${varname}::visible_any"]:-}"
    
    # No conditions = always visible
    if [[ -z "$visible_all" && -z "$visible_any" ]]; then
        return 0
    fi
    
    # Evaluate visible_all (all conditions must be true)
    if [[ -n "$visible_all" ]]; then
        if ! _nds_cfg_eval_condition_all "$visible_all"; then
            return 1
        fi
    fi
    
    # Evaluate visible_any (at least one condition must be true)
    if [[ -n "$visible_any" ]]; then
        if ! _nds_cfg_eval_condition_any "$visible_any"; then
            return 1
        fi
    fi
    
    return 0
}

# ----------------------------------------------------------------------------------
# CONDITION EVALUATION LOGIC
# ----------------------------------------------------------------------------------

# Evaluate condition where ALL expressions must be true
# Format: "VAR1==value1 VAR2!=value2"
_nds_cfg_eval_condition_all() {
    local condition="$1"
    
    # Split by spaces
    local expressions
    read -ra expressions <<< "$condition"
    
    for expr in "${expressions[@]}"; do
        if ! _nds_cfg_eval_expression "$expr"; then
            return 1
        fi
    done
    
    return 0
}

# Evaluate condition where ANY expression must be true
# Format: "VAR1==value1 VAR2!=value2"
_nds_cfg_eval_condition_any() {
    local condition="$1"
    
    # Split by spaces
    local expressions
    read -ra expressions <<< "$condition"
    
    for expr in "${expressions[@]}"; do
        if _nds_cfg_eval_expression "$expr"; then
            return 0
        fi
    done
    
    return 1
}

# Evaluate a single expression
# Supports: == != < > <= >=
_nds_cfg_eval_expression() {
    local expr="$1"
    
    # Parse expression
    local var op value
    
    if [[ "$expr" =~ ^([A-Z_]+)(==|!=|<=|>=|[<>])(.*)$ ]]; then
        var="${BASH_REMATCH[1]}"
        op="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[3]}"
    else
        error "Invalid visibility expression: $expr"
        return 1
    fi
    
    # Get current value
    local current="${CFG_SETTINGS["${var}::value"]:-}"
    
    # Evaluate based on operator
    case "$op" in
        ==)
            [[ "$current" == "$value" ]]
            ;;
        !=)
            [[ "$current" != "$value" ]]
            ;;
        \<)
            _nds_cfg_compare_values "$current" "$value" "lt"
            ;;
        \>)
            _nds_cfg_compare_values "$current" "$value" "gt"
            ;;
        \<=)
            _nds_cfg_compare_values "$current" "$value" "le"
            ;;
        \>=)
            _nds_cfg_compare_values "$current" "$value" "ge"
            ;;
        *)
            error "Unknown operator: $op"
            return 1
            ;;
    esac
}

# Compare two values (numeric if both are numbers, otherwise string)
_nds_cfg_compare_values() {
    local val1="$1"
    local val2="$2"
    local op="$3"
    
    # Check if both are numeric
    if [[ "$val1" =~ ^[0-9]+$ && "$val2" =~ ^[0-9]+$ ]]; then
        # Numeric comparison
        case "$op" in
            lt) [[ $val1 -lt $val2 ]] ;;
            gt) [[ $val1 -gt $val2 ]] ;;
            le) [[ $val1 -le $val2 ]] ;;
            ge) [[ $val1 -ge $val2 ]] ;;
        esac
    else
        # String comparison
        case "$op" in
            lt) [[ "$val1" < "$val2" ]] ;;
            gt) [[ "$val1" > "$val2" ]] ;;
            le) [[ "$val1" < "$val2" || "$val1" == "$val2" ]] ;;
            ge) [[ "$val1" > "$val2" || "$val1" == "$val2" ]] ;;
        esac
    fi
}
