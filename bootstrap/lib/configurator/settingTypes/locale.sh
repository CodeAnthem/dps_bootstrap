#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   SettingType - Locale
# Feature:       Locale validation and selection
# ==================================================================================================

_locale_promptHint() {
    echo "(e.g., en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8)"
}

_locale_validate() {
    local value="$1"
    
    # Basic locale format: language_COUNTRY.encoding
    # Examples: en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8
    [[ "$value" =~ ^[a-z]{2}_[A-Z]{2}\.(UTF-8|utf8)$ ]]
}

_locale_normalize() {
    local value="$1"
    # Normalize to UTF-8 (not utf8)
    echo "${value/.utf8/.UTF-8}"
}

_locale_errorCode() {
    echo "Invalid locale format. Use: language_COUNTRY.UTF-8 (e.g., en_US.UTF-8)"
}

# Auto-register this settingType
nds_cfg_settingType_register "locale"
