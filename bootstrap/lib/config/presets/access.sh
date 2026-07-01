#!/usr/bin/env bash
# ==================================================================================================
# NDS - Access preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-01
# ==================================================================================================

access_defaults() {
    nds_cfg_set ADMIN_USER "admin"
    nds_cfg_set ADMIN_PASSWORD_AUTO "true"
    nds_cfg_set ADMIN_PASSWORD_LENGTH "32"
    nds_cfg_set ADMIN_PASSWORD ""
    nds_cfg_set ADMIN_SSH_KEY ""
    nds_cfg_set SUDO_PASSWORD_REQUIRED "true"
    nds_cfg_set SSH_ENABLE "true"
    nds_cfg_set SSH_PORT "22"
    nds_cfg_set SSH_PASSWORD_AUTH "true"
}

access_configure() {
    nds_cfg_section_title "Access"
    nds_cfg_ask_username ADMIN_USER "Admin username" "admin" true
    nds_cfg_ask_toggle ADMIN_PASSWORD_AUTO "Auto-generate admin password" true
    if nds_cfg_true ADMIN_PASSWORD_AUTO; then
        nds_cfg_ask_int ADMIN_PASSWORD_LENGTH "Admin password length (bytes)" 32 16 128
    else
        nds_cfg_ask_secret ADMIN_PASSWORD "Admin password" 12 true
    fi
    nds_cfg_ask_string ADMIN_SSH_KEY "Admin SSH public key (optional)" "" false
    nds_cfg_ask_toggle SUDO_PASSWORD_REQUIRED "Sudo requires password" true
    nds_cfg_ask_toggle SSH_ENABLE "Enable SSH" true
    if nds_cfg_true SSH_ENABLE; then
        nds_cfg_ask_port SSH_PORT "SSH port" 22
        nds_cfg_ask_toggle SSH_PASSWORD_AUTH "Allow SSH password login" true
    fi
}

access_summary() {
    nds_cfg_summary_row "Admin user" "$(nds_cfg_get ADMIN_USER)"
    nds_cfg_summary_row "Auto-generate password" "$(nds_cfg_display_toggle "$(nds_cfg_get ADMIN_PASSWORD_AUTO)")"
    nds_cfg_summary_row "SSH" "$(nds_cfg_display_toggle "$(nds_cfg_get SSH_ENABLE)")"
    if nds_cfg_true SSH_ENABLE; then
        nds_cfg_summary_row "SSH password login" "$(nds_cfg_display_toggle "$(nds_cfg_get SSH_PASSWORD_AUTH)")"
    fi
}

access_validate() {
    if nds_cfg_is ADMIN_PASSWORD_AUTO false && [[ -z "$(nds_cfg_get ADMIN_PASSWORD)" ]]; then
        validation_error "Admin password is required when auto-generate is off"
        return 1
    fi
    if nds_cfg_true SSH_ENABLE && nds_cfg_is SSH_PASSWORD_AUTH false && [[ -z "$(nds_cfg_get ADMIN_SSH_KEY)" ]]; then
        validation_error "SSH password login is off and no admin SSH key is set"
        return 1
    fi
    return 0
}

NDS_PRESET_PRIORITY=15
NDS_PRESET_DISPLAY="Access"
