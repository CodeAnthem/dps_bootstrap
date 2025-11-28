#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   SettingType - Keyboard Variant
# Feature:       Keyboard variant selection with layout-specific hints
# ==================================================================================================

_keyboardVariant_promptHint() {
    # Get current keyboard layout to show relevant variants
    local layout="${CFG_SETTINGS["KEYBOARD_LAYOUT::value"]:-us}"
    
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

_keyboardVariant_validate() {
    local value="$1"
    
    # Empty is valid (means standard layout)
    [[ -z "$value" ]] && return 0
    
    # Alphanumeric with underscores and hyphens
    [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]
}

_keyboardVariant_normalize() {
    local value="$1"
    # Return as-is (variants are case-sensitive in X11)
    echo "$value"
}

_keyboardVariant_errorCode() {
    echo "Invalid keyboard variant. Use alphanumeric characters, hyphens, underscores, or leave empty"
}

# Auto-register this settingType
nds_cfg_settingType_register "keyboardVariant"
