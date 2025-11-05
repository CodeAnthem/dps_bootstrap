#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - SettingTypes Public API
# Feature:       Auto-registration and hook discovery for settingTypes
# ==================================================================================================

# =============================================================================
# SETTINGTYPE REGISTRATION
# =============================================================================
echo "loaded settingTypes"
# Register a settingType by auto-detecting its hook functions
# Usage: nds_cfg_settingType_register "diskSize"
nds_cfg_settingType_register() {
    local type="$1"
    
    # Get list of all functions starting with _${type}_
    local fnlist
    fnlist="$(declare -F | awk '{print $3}' | grep -E "^_${type}_")"
    
    # Standard hooks to detect
    local hooks=(prompt promptHint validate errorCode normalize display apply)
    
    for hook in "${hooks[@]}"; do
        local func="_${type}_${hook}"
        
        # Check if function exists
        if grep -qw "$func" <<< "$fnlist"; then
            CFG_SETTINGTYPES["${type}::${hook}"]="$func"
        else
            # Assign generic fallback for critical hooks
            case "$hook" in
                prompt)
                    CFG_SETTINGTYPES["${type}::${hook}"]="_generic_prompt"
                    ;;
                display)
                    CFG_SETTINGTYPES["${type}::${hook}"]="_generic_display"
                    ;;
                errorCode)
                    CFG_SETTINGTYPES["${type}::${hook}"]="_generic_errorCode"
                    ;;
                validate)
                    # Validate is required - no fallback
                    error "SettingType '$type' missing required _${type}_validate function"
                    return 1
                    ;;
            esac
        fi
    done
    
    # Add to master list
    CFG_ALL_SETTINGTYPES+=("$type")
    
    return 0
}

# =============================================================================
# GENERIC FALLBACK FUNCTIONS
# =============================================================================

# Generic prompt function (basic text input)
_generic_prompt() {
    local display="$1"
    local current="$2"
    local type="$3"
    
    # Get hint if available
    local hint=""
    local hintFunc="${CFG_SETTINGTYPES["${type}::promptHint"]:-}"
    [[ -n "$hintFunc" ]] && hint=$("$hintFunc")
    
    # Display prompt
    if [[ -n "$hint" ]]; then
        printf "  %-20s [%s] %s: " "$display" "$current" "$hint" >&2
    else
        printf "  %-20s [%s]: " "$display" "$current" >&2
    fi
    
    # Read input
    local value
    read -r value < /dev/tty
    
    # Empty = keep current
    [[ -z "$value" ]] && echo "$current" && return 0
    
    echo "$value"
}

# Generic display function (shows value as-is)
_generic_display() {
    local value="$1"
    echo "$value"
}

# Generic error code function
_generic_errorCode() {
    local value="$1"
    echo "Invalid value: $value"
}

# =============================================================================
# SETTINGTYPE HOOK EXECUTION
# =============================================================================

# Execute a settingType hook with given arguments
# Usage: nds_cfg_settingType_call "diskSize" "validate" "8G"
nds_cfg_settingType_call() {
    local type="$1"
    local hook="$2"
    shift 2
    
    local func="${CFG_SETTINGTYPES["${type}::${hook}"]:-}"
    
    if [[ -z "$func" ]]; then
        error "SettingType '$type' has no hook '$hook'"
        return 1
    fi
    
    "$func" "$@"
}
