#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   Configuration Module - Region Settings
# Feature:       Timezone, locale, and keyboard configuration
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
region_init_callback() {
    nds_field_declare TIMEZONE \
        display="Timezone" \
        input=timezone \
        required=true \
        default="UTC"
    
    nds_field_declare LOCALE_MAIN \
        display="Primary Locale" \
        input=locale \
        required=true \
        default="en_US.UTF-8"
    
    nds_field_declare LOCALE_EXTRA \
        display="Additional Locales" \
        input=string \
        default="de_DE.UTF-8 fr_FR.UTF-8"
    
    nds_field_declare KEYBOARD_LAYOUT \
        display="Keyboard Layout" \
        input=choice \
        required=true \
        default="us" \
        options="us|de|fr|uk|es|it|dvorak|colemak"
    
    nds_field_declare KEYBOARD_VARIANT \
        display="Keyboard Variant" \
        input=string \
        default=""
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
# region_validate_extra() {
#     # No cross-field validation needed
#     return 0
# }
