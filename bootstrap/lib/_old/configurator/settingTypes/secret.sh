#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-11-05
# Description:   SettingType - Secret/Password
# Feature:       Secret input with masked display and hidden prompt
# ==================================================================================================

_secret_validate() {
    local value="$1"
    local minlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::minlen"]:-8}"
    
    # Must meet minimum length
    [[ ${#value} -ge "$minlen" ]]
}

_secret_display() {
    local value="$1"
    local len=${#value}
    
    [[ $len -eq 0 ]] && echo "(not set)" && return
    
    # Special case: very short passwords show only last character
    if [[ $len -lt 9 ]]; then
        local hide=$((len - 1))
        printf '%s%s' "$(printf '%*s' "$hide" '' | tr ' ' '*')" "${value: -1}"
        return
    fi
    
    # Show 10% each side, minimum 1, maximum 4
    local show=$(( len / 10 ))
    show=$(( show < 1 ? 1 : (show > 4 ? 4 : show) ))
    local hide=$((len - show * 2))
    
    printf '%s%s%s' "${value:0:$show}" "$(printf '%*s' "$hide" '' | tr ' ' '*')" "${value: -$show}"
}

_secret_prompt() {
    local display="$1"
    local current="$2"
    local type="$3"
    
    while true; do
        # Show current masked value
        if [[ -n "$current" ]]; then
            printf "  %-20s [%s]: " "$display" "$(_secret_display "$current")" >&2
        else
            printf "  %-20s: " "$display" >&2
        fi
        
        # Read silently (no echo)
        local value
        read -r -s value < /dev/tty
        echo >&2  # new_line after hidden input
        
        # Empty = keep current
        if [[ -z "$value" ]]; then
            echo "$current"
            return 0
        fi
        
        # Validate
        if _secret_validate "$value"; then
            echo "$value"
            return 0
        else
            local error
            error=$(_secret_errorCode "$value")
            console "    Error: $error"
        fi
    done
}

_secret_errorCode() {
    local value="$1"
    local minlen="${CFG_SETTINGS["${CFG_VALIDATOR_CONTEXT}::attr::minlen"]:-8}"
    
    echo "Must be at least $minlen characters"
}

# Auto-register this settingType
nds_cfg_settingType_register "secret"
