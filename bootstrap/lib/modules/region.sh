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
        display="Keyboard Variant (optional)" \
        input=keyboard_variant \
        default="" \
        help="Layout modification - common: nodeadkeys (de/fr), dvorak/colemak (us), abnt2 (br) - leave empty for standard"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
# Used to have another sorting
region_get_active_fields() {
    echo "TIMEZONE"
    echo "LOCALE_MAIN"
    echo "LOCALE_EXTRA"
    echo "KEYBOARD_LAYOUT"
    echo "KEYBOARD_VARIANT"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_region_auto() {
    local timezone locale_main locale_extra keyboard_layout keyboard_variant
    timezone=$(nds_config_get "region" "TIMEZONE")
    locale_main=$(nds_config_get "region" "LOCALE_MAIN")
    locale_extra=$(nds_config_get "region" "LOCALE_EXTRA")
    keyboard_layout=$(nds_config_get "region" "KEYBOARD_LAYOUT")
    keyboard_variant=$(nds_config_get "region" "KEYBOARD_VARIANT")
    
    _nixcfg_region_generate "$timezone" "$locale_main" "$locale_extra" "$keyboard_layout" "$keyboard_variant"
}

# Manual mode: explicit parameters
nds_nixcfg_region() {
    local timezone="${1:-UTC}"
    local locale_main="${2:-en_US.UTF-8}"
    local locale_extra="${3:-}"
    local keyboard_layout="${4:-us}"
    local keyboard_variant="${5:-}"
    
    _nixcfg_region_generate "$timezone" "$locale_main" "$locale_extra" "$keyboard_layout" "$keyboard_variant"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_region_generate() {
    local timezone="$1"
    local locale_main="$2"
    local locale_extra="$3"
    local keyboard_layout="$4"
    local keyboard_variant="$5"
    
    local output
    
    # Build config block
    output="time.timeZone = \"$timezone\";

i18n.defaultLocale = \"$locale_main\";"
    
    # Extra locales if specified
    if [[ -n "$locale_extra" ]]; then
        output+="
i18n.extraLocaleSettings = {"
        # Split by space and add each locale
        local locale
        for locale in $locale_extra; do
            output+="
  LC_ALL = \"$locale\";"
        done
        output+="
};"
    fi
    
    output+="

"
    
    # Keyboard layout
    if [[ -n "$keyboard_variant" ]]; then
        output+="services.xserver.xkb = {
  layout = \"$keyboard_layout\";
  variant = \"$keyboard_variant\";
};"
    else
        output+="services.xserver.xkb.layout = \"$keyboard_layout\";"
    fi
    
    nds_nixcfg_register "region" "$output" 40
}
