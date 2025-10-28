#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   Input Handler - Secret/Password
# Feature:       Secret input with masked display and hidden prompt
# ==================================================================================================

# =============================================================================
# SECRET INPUT
# =============================================================================

validate_secret() {
    local value="$1"
    local minlen
    minlen=$(input_opt "minlen" "8")
    
    # Must meet minimum length
    [[ ${#value} -ge "$minlen" ]] || return 2
    
    return 0
}

# Display masked value - show 10% each side, last char only if < 9
display_secret() {
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

# Custom prompt for secret input (uses read -s for hidden input)
prompt_secret() {
    local display="$1"
    local current="$2"
    
    while true; do
        # Show current masked value
        if [[ -n "$current" ]]; then
            printf "  %-20s [%s]: " "$display" "$(display_secret "$current")" >&2
        else
            printf "  %-20s: " "$display" >&2
        fi
        
        # Read silently (no echo)
        local value
        read -r -s value < /dev/tty
        echo >&2  # Newline after hidden input
        
        # Empty = keep current
        if [[ -z "$value" ]]; then
            echo "$current"
            return 0
        fi
        
        # Validate
        local error_code
        set_input_context "${INPUT_CONTEXT_MODULE}" "${INPUT_CONTEXT_FIELD}"
        validate_secret "$value"
        error_code=$?
        
        if [[ "$error_code" -eq 0 ]]; then
            echo "$value"
            return 0
        else
            local error
            error=$(error_msg_secret "$value" "$error_code")
            console "    Error: $error"
        fi
    done
}

error_msg_secret() {
    local value="$1"
    local code="${2:-0}"
    local minlen
    minlen=$(input_opt "minlen" "8")
    
    case "$code" in
        2)
            echo "Must be at least $minlen characters"
            ;;
        *)
            echo "Invalid secret"
            ;;
    esac
}
