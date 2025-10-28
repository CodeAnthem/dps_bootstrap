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
region_init_callback() {
    # Optional: Country selection for auto-defaults
    nds_field_declare COUNTRY \
        display="Country (optional - sets defaults)" \
        input=country \
        default=""
    
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
        default=""
    
    nds_field_declare KEYBOARD_LAYOUT \
        display="Keyboard Layout" \
        input=keyboard \
        required=true \
        default="us"
    
    nds_field_declare KEYBOARD_VARIANT \
        display="Keyboard Variant" \
        input=string \
        default=""
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
region_get_active_fields() {
    local country
    country=$(nds_config_get "region" "COUNTRY")
    
    # Always show country first (optional)
    echo "COUNTRY"
    
    # If country is set, apply defaults before showing other fields
    if [[ -n "$country" ]]; then
        # Apply country defaults (timezone, locale, keyboard)
        apply_country_defaults "$country" 2>/dev/null || true
    fi
    
    # Show all other fields
    echo "TIMEZONE"
    echo "LOCALE_MAIN"
    echo "LOCALE_EXTRA"
    echo "KEYBOARD_LAYOUT"
    echo "KEYBOARD_VARIANT"
}

# Note: No need for region_validate_extra() - no cross-field validation
