#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Input Handler - Keyboard Layout
# Feature:       Keyboard layout validation with common layouts
# ==================================================================================================

# ----------------------------------------------------------------------------------
# KEYBOARD INPUT
# ----------------------------------------------------------------------------------

prompt_hint_keyboard() {
    echo "(us, de, fr, uk, es, it, dvorak, colemak, etc.)"
}

validate_keyboard() {
    local value="$1"
    
    # Common keyboard layouts - accept alphanumeric with optional hyphens
    if [[ ! "$value" =~ ^[a-z0-9-]+$ ]]; then
        return 1
    fi
    
    # Length check (keyboard layouts are typically 2-10 chars)
    local len=${#value}
    if [[ $len -lt 2 || $len -gt 15 ]]; then
        return 1
    fi
    
    return 0
}

normalize_keyboard() {
    local value="$1"
    # Lowercase
    echo "${value,,}"
}

error_msg_keyboard() {
    local value="$1"
    local code="${2:-0}"
    
    echo "Invalid keyboard layout. Use lowercase layout name (e.g., us, de, dvorak)"
}
