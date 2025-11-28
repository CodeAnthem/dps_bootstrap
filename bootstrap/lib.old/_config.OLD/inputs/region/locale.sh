#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Input Handler - Locale
# Feature:       Locale validation and selection
# ==================================================================================================

# ----------------------------------------------------------------------------------
# LOCALE INPUT
# ----------------------------------------------------------------------------------

prompt_hint_locale() {
    echo "(e.g., en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8)"
}

validate_locale() {
    local value="$1"
    
    # Basic locale format: language_COUNTRY.encoding
    # Examples: en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8
    if [[ ! "$value" =~ ^[a-z]{2}_[A-Z]{2}\.(UTF-8|utf8)$ ]]; then
        return 1
    fi
    
    return 0
}

normalize_locale() {
    local value="$1"
    # Normalize to UTF-8 (not utf8)
    echo "${value/.utf8/.UTF-8}"
}

error_msg_locale() {
    local value="$1"
    local code="${2:-0}"
    
    echo "Invalid locale format. Use: language_COUNTRY.UTF-8 (e.g., en_US.UTF-8)"
}
