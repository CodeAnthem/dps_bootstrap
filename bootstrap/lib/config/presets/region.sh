#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-28
# Description:   Region Module - Configuration
# Feature:       Timezone, locale, and keyboard configuration with optional country-based defaults
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
region_init() {
    nds_configurator_var_declare TIMEZONE \
        display="Timezone" \
        input=timezone \
        required=true \
        default="UTC"
    
    nds_configurator_var_declare LOCALE_MAIN \
        display="Primary Locale" \
        input=locale \
        required=true \
        default="en_US.UTF-8"
    
    nds_configurator_var_declare LOCALE_EXTRA \
        display="Additional Locales" \
        input=string \
        default=""
    
    nds_configurator_var_declare KEYBOARD_LAYOUT \
        display="Keyboard Layout" \
        input=keyboard \
        required=true \
        default="us"
    
    nds_configurator_var_declare KEYBOARD_VARIANT \
        display="Keyboard Variant (optional)" \
        input=keyboard_variant \
        default="" \
        help="Layout modification - common: nodeadkeys (de/fr), dvorak/colemak (us), abnt2 (br) - leave empty for standard"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
# Used to have another sorting
region_get_active() {
    echo "TIMEZONE"
    echo "LOCALE_MAIN"
    echo "LOCALE_EXTRA"
    echo "KEYBOARD_LAYOUT"
    echo "KEYBOARD_VARIANT"
}

