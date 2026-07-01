#!/usr/bin/env bash
# ==================================================================================================
# NDS - Region preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-01
# ==================================================================================================

region_defaults() {
    nds_cfg_set TIMEZONE "UTC"
    nds_cfg_set LOCALE_MAIN "en_US.UTF-8"
    nds_cfg_set LOCALE_EXTRA ""
    nds_cfg_set KEYBOARD_LAYOUT "us"
    nds_cfg_set KEYBOARD_VARIANT ""
}

region_configure() {
    nds_cfg_section_title "Region"
    nds_cfg_ask_timezone TIMEZONE "Timezone" "UTC"
    nds_cfg_ask_locale LOCALE_MAIN "Primary locale" "en_US.UTF-8"
    nds_cfg_ask_string LOCALE_EXTRA "Additional locales" "" false
    nds_cfg_ask_keyboard KEYBOARD_LAYOUT "Keyboard layout" "us"
    nds_cfg_ask_string KEYBOARD_VARIANT "Keyboard variant (optional)" "" false
}

region_summary() {
    nds_cfg_summary_row "Timezone" "$(nds_cfg_get TIMEZONE)"
    nds_cfg_summary_row "Locale" "$(nds_cfg_get LOCALE_MAIN)"
    nds_cfg_summary_row "Keyboard" "$(nds_cfg_get KEYBOARD_LAYOUT)"
}

region_validate() {
    validate_timezone "$(nds_cfg_get TIMEZONE)" || { validation_error "Invalid timezone"; return 1; }
    validate_locale "$(nds_cfg_get LOCALE_MAIN)" || { validation_error "Invalid locale"; return 1; }
    return 0
}

NDS_PRESET_PRIORITY=50
NDS_PRESET_DISPLAY="Region"
