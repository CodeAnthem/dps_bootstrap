#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Input Handler - Keyboard Variant Selection
# Feature:       Keyboard variant selection with layout-specific options
# ==================================================================================================

# ----------------------------------------------------------------------------------
# KEYBOARD VARIANT INPUT
# ----------------------------------------------------------------------------------

prompt_hint_keyboard_variant() {
    # Get current keyboard layout to show relevant variants
    local layout
    layout=$(nds_cfg_get "KEYBOARD_LAYOUT" 2>/dev/null || echo "us")
    
    case "$layout" in
        us)
            echo "(dvorak, colemak, intl, altgr-intl, or empty for standard)"
            ;;
        de)
            echo "(nodeadkeys, neo, bone, deadacute, or empty for standard)"
            ;;
        fr)
            echo "(oss, nodeadkeys, bepo, latin9, or empty for standard)"
            ;;
        ch)
            echo "(de_nodeadkeys, fr_nodeadkeys, de_mac, fr_mac, or empty for standard)"
            ;;
        br)
            echo "(abnt2, nodeadkeys, or empty for standard)"
            ;;
        uk|gb)
            echo "(extd, intl, mac, or empty for standard)"
            ;;
        *)
            echo "(variant for $layout layout, or empty for standard)"
            ;;
    esac
}

validate_keyboard_variant() {
    local value="$1"
    
    # Empty is valid (means standard layout)
    if [[ -z "$value" ]]; then
        return 0
    fi
    
    # Alphanumeric with underscores and hyphens
    if [[ ! "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    return 0
}

normalize_keyboard_variant() {
    local value="$1"
    
    # Return as-is (variants are case-sensitive in X11)
    echo "$value"
}

error_msg_keyboard_variant() {
    echo "Invalid keyboard variant. Use alphanumeric characters, hyphens, underscores, or leave empty"
}
