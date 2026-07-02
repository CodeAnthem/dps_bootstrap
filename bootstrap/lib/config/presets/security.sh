#!/usr/bin/env bash
# ==================================================================================================
# NDS - Security preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# ==================================================================================================

security_defaults() {
    nds_cfg_set SECURITY_SECURE_BOOT "false"
    nds_cfg_set SECURITY_SECURE_BOOT_METHOD "lanzaboote"
    nds_cfg_set SECURITY_FIREWALL_ENABLE "true"
    nds_cfg_set SECURITY_HARDENING_ENABLE "true"
    nds_cfg_set SECURITY_FAIL2BAN_ENABLE "false"
}

security_configure() {
    nds_cfg_section_title "Security"
    nds_cfg_ask_toggle SECURITY_SECURE_BOOT "Enable Secure Boot" false
    if nds_cfg_true SECURITY_SECURE_BOOT; then
        nds_cfg_ask_choice SECURITY_SECURE_BOOT_METHOD "Secure Boot method" "lanzaboote|sbctl" "" "lanzaboote"
    fi
    nds_cfg_ask_toggle SECURITY_FIREWALL_ENABLE "Enable firewall" true
    nds_cfg_ask_toggle SECURITY_HARDENING_ENABLE "Apply security hardening" true
    nds_cfg_ask_toggle SECURITY_FAIL2BAN_ENABLE "Enable Fail2Ban" false
}

security_summary() {
    nds_cfg_summary_row "Secure Boot" "$(nds_cfg_display_toggle "$(nds_cfg_get SECURITY_SECURE_BOOT)")"
    nds_cfg_summary_row "Firewall" "$(nds_cfg_display_toggle "$(nds_cfg_get SECURITY_FIREWALL_ENABLE)")"
    nds_cfg_summary_row "Hardening" "$(nds_cfg_display_toggle "$(nds_cfg_get SECURITY_HARDENING_ENABLE)")"
}

security_validate() {
    return 0
}

NDS_PRESET_PRIORITY=40
NDS_PRESET_DISPLAY="Security"
