#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-02
# Description:   NixOS Config Generation - Region Module
# Feature:       Timezone, locale, and keyboard configuration
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_region_auto() {
    local timezone locale_main locale_extra keyboard_layout keyboard_variant
    timezone=$(nds_config_get "region" "REGION_TIMEZONE")
    locale_main=$(nds_config_get "region" "REGION_LOCALE_MAIN")
    locale_extra=$(nds_config_get "region" "REGION_LOCALE_EXTRA")
    keyboard_layout=$(nds_config_get "region" "REGION_KEYBOARD_LAYOUT")
    keyboard_variant=$(nds_config_get "region" "REGION_KEYBOARD_VARIANT")
    
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
    
    # Dynamic pieces built first, then dropped into a quoted-heredoc skeleton
    # via @@TOKEN@@ substitution (no bash expansion, no escaping).
    local extra_block=""
    if [[ -n "$locale_extra" ]]; then
        extra_block=$'\ni18n.extraLocaleSettings = {'
        local locale
        for locale in $locale_extra; do
            extra_block+=$'\n  LC_ALL = "'"$locale"'";'
        done
        extra_block+=$'\n};'
    fi

    local kb_block
    if [[ -n "$keyboard_variant" ]]; then
        kb_block=$(nds_nixcfg_subst "$(cat <<'EOF'
services.xserver.xkb = {
  layout = "@@LAYOUT@@";
  variant = "@@VARIANT@@";
};
EOF
)" @@LAYOUT@@ "$keyboard_layout" @@VARIANT@@ "$keyboard_variant")
    else
        kb_block=$(nds_nixcfg_subst 'services.xserver.xkb.layout = "@@LAYOUT@@";' @@LAYOUT@@ "$keyboard_layout")
    fi

    local output
    output=$(nds_nixcfg_subst "$(cat <<'EOF'
time.timeZone = "@@TIMEZONE@@";

i18n.defaultLocale = "@@LOCALE_MAIN@@";@@EXTRA_BLOCK@@

@@KB_BLOCK@@
EOF
)" @@TIMEZONE@@ "$timezone" @@LOCALE_MAIN@@ "$locale_main" @@EXTRA_BLOCK@@ "$extra_block" @@KB_BLOCK@@ "$kb_block")

    nds_nixcfg_register "region" "$output" 40
}
