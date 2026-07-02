#!/usr/bin/env bash
# ==================================================================================================
# NDS - Encryption preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# ==================================================================================================

encryption_defaults() {
    nds_cfg_set ENCRYPTION "true"
    nds_cfg_set ENCRYPTION_PASSWORD "true"
    nds_cfg_set ENCRYPTION_PASSWORD_AUTO "true"
    nds_cfg_set ENCRYPTION_PASSWORD_LENGTH "32"
    nds_cfg_set ENCRYPTION_KEY "false"
    nds_cfg_set ENCRYPTION_KEY_AUTO "true"
    nds_cfg_set ENCRYPTION_KEY_LENGTH "4096"
    nds_cfg_set ENCRYPTION_KEY_BOOT_DEVICE ""
    nds_cfg_set ENCRYPTION_KEY_BOOT_FILE ""
    nds_cfg_set ENCRYPTION_REMOTE_UNLOCK "false"
    nds_cfg_set ENCRYPTION_REMOTE_SSH_KEY ""
    nds_cfg_set ENCRYPTION_REMOTE_NETWORK "dhcp"
    nds_cfg_set ENCRYPTION_REMOTE_PORT "2222"
}

encryption_configure() {
    nds_cfg_section_title "Encryption"
    nds_cfg_ask_toggle ENCRYPTION "Enable encryption" true
    nds_cfg_true ENCRYPTION || return 0

    nds_cfg_ask_toggle ENCRYPTION_PASSWORD "Use password" true
    nds_cfg_ask_toggle ENCRYPTION_KEY "Use key (USB stick)" false
    nds_cfg_ask_toggle ENCRYPTION_REMOTE_UNLOCK "Enable SSH remote unlock in initrd" false

    if nds_cfg_true ENCRYPTION_PASSWORD; then
        nds_cfg_ask_toggle ENCRYPTION_PASSWORD_AUTO "Auto-generate password" true
        if nds_cfg_true ENCRYPTION_PASSWORD_AUTO; then
            nds_cfg_ask_int ENCRYPTION_PASSWORD_LENGTH "Password length (characters)" 32 16 128
        fi
    fi

    if nds_cfg_true ENCRYPTION_KEY; then
        nds_cfg_ask_toggle ENCRYPTION_KEY_AUTO "Auto-generate key" true
        if nds_cfg_true ENCRYPTION_KEY_AUTO; then
            nds_cfg_ask_int ENCRYPTION_KEY_LENGTH "Key length (bytes)" 4096 512 8192
        fi
        nds_cfg_ask_string ENCRYPTION_KEY_BOOT_DEVICE "USB device path at boot" "" true
        nds_cfg_ask_string ENCRYPTION_KEY_BOOT_FILE "Key file on USB (empty = raw device)" "" false
    fi

    if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK; then
        nds_cfg_ask_string ENCRYPTION_REMOTE_SSH_KEY "Authorized SSH public key" "" true
        nds_cfg_ask_choice ENCRYPTION_REMOTE_NETWORK "Initrd network mode" "dhcp|static" \
            "dhcp=DHCP (automatic)|static=Static IP (from network settings)" "dhcp"
        # Default 2222 keeps the initrd sshd off the booted system's port 22, so
        # the two different host keys never collide in known_hosts.
        nds_cfg_ask_port ENCRYPTION_REMOTE_PORT "Remote unlock SSH port" 2222
    fi
}

encryption_summary() {
    nds_cfg_summary_row "Encryption" "$(nds_cfg_display_toggle "$(nds_cfg_get ENCRYPTION)")"
    nds_cfg_true ENCRYPTION || return 0
    nds_cfg_summary_row "Password" "$(nds_cfg_display_toggle "$(nds_cfg_get ENCRYPTION_PASSWORD)")"
    nds_cfg_summary_row "USB key" "$(nds_cfg_display_toggle "$(nds_cfg_get ENCRYPTION_KEY)")"
    nds_cfg_summary_row "Remote unlock" "$(nds_cfg_display_toggle "$(nds_cfg_get ENCRYPTION_REMOTE_UNLOCK)")"
}

encryption_prompt_errors() {
    nds_cfg_section_title "Encryption"
    while ! encryption_validate &>/dev/null; do
        if ! nds_cfg_true ENCRYPTION_PASSWORD && ! nds_cfg_true ENCRYPTION_KEY; then
            nds_cfg_ask_toggle ENCRYPTION_PASSWORD "Use password" true
            continue
        fi
        if nds_cfg_true ENCRYPTION_KEY && [[ -z "$(nds_cfg_get ENCRYPTION_KEY_BOOT_DEVICE)" ]]; then
            nds_cfg_ask_string ENCRYPTION_KEY_BOOT_DEVICE "USB device path at boot" "" true
            continue
        fi
        if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK && [[ -z "$(nds_cfg_get ENCRYPTION_REMOTE_SSH_KEY)" ]]; then
            nds_cfg_ask_string ENCRYPTION_REMOTE_SSH_KEY "Authorized SSH public key" "" true
            continue
        fi
        break
    done
}

encryption_validate() {
    nds_cfg_true ENCRYPTION || return 0

    if ! nds_cfg_true ENCRYPTION_PASSWORD && ! nds_cfg_true ENCRYPTION_KEY; then
        validation_error "At least one unlock method (password or key) must be enabled"
        return 1
    fi

    if nds_cfg_true ENCRYPTION_KEY && [[ -z "$(nds_cfg_get ENCRYPTION_KEY_BOOT_DEVICE)" ]]; then
        validation_error "USB device path is required when key unlock is enabled"
        return 1
    fi

    if nds_cfg_true ENCRYPTION_KEY && ! nds_cfg_true ENCRYPTION_PASSWORD; then
        warn "Key-only mode: if the USB is lost, the system cannot boot."
    fi

    if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK; then
        [[ -n "$(nds_cfg_get ENCRYPTION_REMOTE_SSH_KEY)" ]] || {
            validation_error "Authorized SSH public key is required for remote unlock"
            return 1
        }
        if nds_cfg_is ENCRYPTION_REMOTE_NETWORK static && [[ -z "$(nds_cfg_get NETWORK_IP)" ]]; then
            validation_error "Static remote unlock needs NETWORK_IP — set it in Network, or use DHCP"
            return 1
        fi
        if ! nds_cfg_true ENCRYPTION_PASSWORD; then
            warn "Remote unlock needs a password slot — SSH cannot unlock key-only disks."
        fi
    fi
    return 0
}

NDS_PRESET_PRIORITY=21
NDS_PRESET_DISPLAY="Encryption"
