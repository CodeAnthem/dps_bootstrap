#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-01
# Description:   LUKS unlock Nix config (keyfile on USB; no embedded key)
# Feature:       Emits keyFile / fallbackToPassword / systemd mount options.
#                The LUKS device UUID comes from hardware-configuration.nix
#                (auto-generated), so this block only adds unlock behavior.
# ==================================================================================================

# Auto-mode: reads from the disk configurator answers.
# Modes:
#   password only  -> no extra config (NixOS prompts at boot / via initrd SSH)
#   key only (raw) -> keyFile = USB device, keyFileSize, keyFileTimeout
#   key only (file)-> systemd mount of USB + keyFile = file on mount, keyFileTimeout
#   both (raw)     -> keyFile + fallbackToPassword + short keyFileTimeout
#   both (file)    -> systemd mount + keyFile + fallbackToPassword
nds_nixcfg_luks_auto() {
    local encryption use_password use_key key_device key_file key_length
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    [[ "$encryption" == "true" ]] || return 0

    use_password=$(nds_config_get "encryption" "ENCRYPTION_PASSWORD")
    use_key=$(nds_config_get "encryption" "ENCRYPTION_KEY")

    # Password-only: hardware-configuration.nix already declares the device;
    # NixOS prompts for the passphrase at boot (or via initrd SSH). Nothing to add.
    [[ "$use_key" == "true" ]] || return 0

    key_device=$(nds_config_get "encryption" "ENCRYPTION_KEY_BOOT_DEVICE")
    key_file=$(nds_config_get "encryption" "ENCRYPTION_KEY_BOOT_FILE")
    key_length=$(nds_config_get "encryption" "ENCRYPTION_KEY_LENGTH")

    local timeout
    if [[ "$use_password" == "true" ]]; then
        # Both: try the key briefly, then fall back to a password prompt.
        timeout=10
    else
        # Key only: give the USB more time to settle, no fallback.
        timeout=30
    fi

    local block=""
    local mount_block=""

    # File-on-filesystem: mount the USB in the initrd before reading the key.
    if [[ -n "$key_file" ]]; then
        mount_block=$(cat <<EOF
# Mount the USB stick holding the LUKS keyfile before unlock
boot.initrd.systemd.mounts = [{
  what = "${key_device}";
  where = "/mnt-keyusb";
  type = "auto";
}];
EOF
)
        local key_path="/mnt-keyusb/${key_file}"
        # Strip a leading slash from the user-provided file path to avoid //.
        key_path="/mnt-keyusb/${key_file#/}"
    else
        # Raw device: key bytes read directly from the block device.
        local key_path="${key_device}"
    fi

    if [[ "$use_password" == "true" ]]; then
        if [[ -n "$key_file" ]]; then
            block=$(cat <<EOF
${mount_block}

# LUKS unlock: keyfile on mounted USB, fall back to password prompt
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "${key_path}";
  keyFileTimeout = ${timeout};
  fallbackToPassword = true;
};
EOF
)
        else
            block=$(cat <<EOF
${mount_block}

# LUKS unlock: raw keyfile on USB device, fall back to password prompt
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "${key_path}";
  keyFileSize = ${key_length};
  keyFileTimeout = ${timeout};
  fallbackToPassword = true;
};
EOF
)
        fi
    else
        if [[ -n "$key_file" ]]; then
            block=$(cat <<EOF
${mount_block}

# LUKS unlock: keyfile on mounted USB (no password fallback)
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "${key_path}";
  keyFileTimeout = ${timeout};
};
EOF
)
        else
            block=$(cat <<EOF
${mount_block}

# LUKS unlock: raw keyfile on USB device (no password fallback)
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "${key_path}";
  keyFileSize = ${key_length};
  keyFileTimeout = ${timeout};
};
EOF
)
        fi
    fi

    nds_nixcfg_register "luks" "$block" 12
}
