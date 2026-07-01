#!/usr/bin/env bash
# ==================================================================================================
# NDS - Security preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-01
# ==================================================================================================

security_defaults() {
    nds_cfg_set SECURE_BOOT "false"
    nds_cfg_set SECURE_BOOT_METHOD "lanzaboote"
    nds_cfg_set FIREWALL_ENABLE "true"
    nds_cfg_set HARDENING_ENABLE "true"
    nds_cfg_set FAIL2BAN_ENABLE "false"
}

security_configure() {
    nds_cfg_section_title "Security"
    nds_cfg_ask_toggle SECURE_BOOT "Enable Secure Boot" false
    if nds_cfg_true SECURE_BOOT; then
        nds_cfg_ask_choice SECURE_BOOT_METHOD "Secure Boot method" "lanzaboote|sbctl" "" "lanzaboote"
    fi
    nds_cfg_ask_toggle FIREWALL_ENABLE "Enable firewall" true
    nds_cfg_ask_toggle HARDENING_ENABLE "Apply security hardening" true
    nds_cfg_ask_toggle FAIL2BAN_ENABLE "Enable Fail2Ban" false
}

security_summary() {
    nds_cfg_summary_row "Secure Boot" "$(nds_cfg_display_toggle "$(nds_cfg_get SECURE_BOOT)")"
    nds_cfg_summary_row "Firewall" "$(nds_cfg_display_toggle "$(nds_cfg_get FIREWALL_ENABLE)")"
    nds_cfg_summary_row "Hardening" "$(nds_cfg_display_toggle "$(nds_cfg_get HARDENING_ENABLE)")"
}

security_validate() {
    return 0
}

NDS_PRESET_PRIORITY=40
NDS_PRESET_DISPLAY="Security"
