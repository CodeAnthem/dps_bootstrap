#!/usr/bin/env bash
# ==================================================================================================
# NDS - Encryption preset (LUKS2 unlock, remote unlock)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-01
# Description:   Disk encryption: password/key slots and initrd SSH remote unlock
# ==================================================================================================

encryption_init() {
    nds_configurator_preset_set_display "encryption" "Encryption"
    nds_configurator_preset_set_priority "encryption" 21

    nds_configurator_var_declare ENCRYPTION \
        display="Enable Encryption" \
        input=toggle \
        default=true \
        required=true

    nds_configurator_var_declare ENCRYPTION_PASSWORD \
        display="Use Password" \
        input=toggle \
        default=true \
        help="LUKS passphrase slot. Prompted at boot (console or via remote unlock SSH)."

    nds_configurator_var_declare ENCRYPTION_PASSWORD_AUTO \
        display="Auto-generate Password" \
        input=toggle \
        default=true \
        help="Generate a random password from /dev/urandom. Disable to type your own."

    nds_configurator_var_declare ENCRYPTION_PASSWORD_LENGTH \
        display="Password Length (bytes)" \
        input=int \
        default=32 \
        min=16 \
        max=128 \
        help="Random bytes from /dev/urandom (hex-encoded). 32 bytes = 256-bit = 64 hex chars."

    nds_configurator_var_declare ENCRYPTION_KEY \
        display="Use Key (USB stick)" \
        input=toggle \
        default=false \
        help="LUKS keyfile slot on a USB stick. Boot reads the key from USB — no prompt. Warning: if the USB is lost or corrupted, the system cannot boot. Consider also enabling a password as fallback."

    nds_configurator_var_declare ENCRYPTION_KEY_AUTO \
        display="Auto-generate Key" \
        input=toggle \
        default=true \
        help="Generate a random keyfile from /dev/urandom. Disable to provide an existing keyfile."

    nds_configurator_var_declare ENCRYPTION_KEY_LENGTH \
        display="Key Length (bytes)" \
        input=int \
        default=4096 \
        min=512 \
        max=8192 \
        help="Random bytes for the keyfile. 4096 is the conventional NixOS default."

    nds_configurator_var_declare ENCRYPTION_KEY_BOOT_DEVICE \
        display="USB device path at boot" \
        input=string \
        default="" \
        required=false \
        help="Block device path where the USB will be at boot, e.g. /dev/disk/by-uuid/..."

    nds_configurator_var_declare ENCRYPTION_KEY_BOOT_FILE \
        display="Key file path on USB (empty = raw device)" \
        input=string \
        default="" \
        required=false \
        help="Empty: key is raw bytes written with dd to the device (no filesystem). Set: key is a file on a mounted USB filesystem, e.g. /key.bin — NixOS mounts the USB in initrd."

    nds_configurator_var_declare ENCRYPTION_REMOTE_UNLOCK \
        display="Enable SSH remote unlock in initrd" \
        input=toggle \
        default=false \
        help="SSH daemon in initrd so you can unlock LUKS over the network at boot."

    nds_configurator_var_declare ENCRYPTION_REMOTE_SSH_KEY \
        display="Authorized SSH public key" \
        input=string \
        default="" \
        required=false \
        help="Your SSH public key (the client key that will connect to the initrd SSH server). Paste the full key, e.g. ssh-ed25519 AAAA... user@host"

    nds_configurator_var_declare ENCRYPTION_REMOTE_NETWORK \
        display="Initrd network mode" \
        input=choice \
        default="dhcp" \
        options="dhcp|static" \
        option_labels="dhcp=DHCP (automatic IP)|static=Static IP (from network settings)" \
        help="How the initrd gets an IP for the SSH server."
}

encryption_get_active() {
    local encryption use_password use_key password_auto use_remote key_auto

    encryption=$(nds_configurator_config_get "ENCRYPTION")
    use_password=$(nds_configurator_config_get "ENCRYPTION_PASSWORD")
    use_key=$(nds_configurator_config_get "ENCRYPTION_KEY")
    password_auto=$(nds_configurator_config_get "ENCRYPTION_PASSWORD_AUTO")
    key_auto=$(nds_configurator_config_get "ENCRYPTION_KEY_AUTO")
    use_remote=$(nds_configurator_config_get "ENCRYPTION_REMOTE_UNLOCK")

    echo "ENCRYPTION"
    [[ "$encryption" != "true" ]] && return 0

    echo "ENCRYPTION_PASSWORD"
    echo "ENCRYPTION_KEY"
    echo "ENCRYPTION_REMOTE_UNLOCK"

    if [[ "$use_password" == "true" ]]; then
        echo "ENCRYPTION_PASSWORD_AUTO"
        if [[ "$password_auto" == "true" ]]; then
            echo "ENCRYPTION_PASSWORD_LENGTH"
        fi
    fi

    if [[ "$use_key" == "true" ]]; then
        echo "ENCRYPTION_KEY_AUTO"
        if [[ "$key_auto" == "true" ]]; then
            echo "ENCRYPTION_KEY_LENGTH"
        fi
        echo "ENCRYPTION_KEY_BOOT_DEVICE"
        echo "ENCRYPTION_KEY_BOOT_FILE"
    fi

    if [[ "$use_remote" == "true" ]]; then
        echo "ENCRYPTION_REMOTE_SSH_KEY"
        echo "ENCRYPTION_REMOTE_NETWORK"
    fi
}

encryption_validate_extra() {
    local encryption use_password use_key use_remote

    encryption=$(nds_configurator_config_get "ENCRYPTION")
    [[ "$encryption" == "true" ]] || return 0

    use_password=$(nds_configurator_config_get "ENCRYPTION_PASSWORD")
    use_key=$(nds_configurator_config_get "ENCRYPTION_KEY")
    use_remote=$(nds_configurator_config_get "ENCRYPTION_REMOTE_UNLOCK")

    if [[ "$use_password" != "true" && "$use_key" != "true" ]]; then
        validation_error "At least one unlock method (password or key) must be enabled"
        return 1
    fi

    if [[ "$use_key" == "true" ]]; then
        local key_device
        key_device=$(nds_configurator_config_get "ENCRYPTION_KEY_BOOT_DEVICE")
        if [[ -z "$key_device" ]]; then
            validation_error "USB device path is required when key unlock is enabled"
            return 1
        fi

        if [[ "$use_password" != "true" ]]; then
            warn "Key-only mode: if the USB is lost, stolen, or corrupted, the system CANNOT boot."
            warn "Consider also enabling a password as fallback."
        fi
    fi

    if [[ "$use_remote" == "true" ]]; then
        local ssh_key
        ssh_key=$(nds_configurator_config_get "ENCRYPTION_REMOTE_SSH_KEY")
        if [[ -z "$ssh_key" ]]; then
            validation_error "Authorized SSH public key is required for remote unlock"
            return 1
        fi

        local net_mode
        net_mode=$(nds_configurator_config_get "ENCRYPTION_REMOTE_NETWORK")
        if [[ "$net_mode" == "static" ]]; then
            local net_ip
            net_ip=$(nds_configurator_config_get "NETWORK_IP")
            if [[ -z "$net_ip" ]]; then
                validation_error "Static remote unlock needs NETWORK_IP — set it in Network, or use DHCP"
                return 1
            fi
        fi

        if [[ "$use_password" != "true" ]]; then
            warn "Remote unlock answers password prompts, but no password slot is enabled."
            warn "SSH will not help unlock the disk. Enable password too, or disable remote unlock."
        fi
    fi

    return 0
}
