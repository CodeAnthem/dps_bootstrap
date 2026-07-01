#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-01
# Description:   LUKS2 encryption setup for NixOS installation
# Feature:       Password and/or keyfile LUKS slots, openssl rand generation
# ==================================================================================================

# =============================================================================
# ENCRYPTION SETUP
# =============================================================================

# Description: Generate or collect unlock secrets (password and/or keyfile)
# and save them to the runtime secrets directory for the backup bundle and
# for _nixinstall_format_luks to read back. Run before partitioning.
# NOTE: This runs under nds_step_exec (a subshell with stderr -> install log),
# so interactive prompts write to /dev/tty explicitly. Do NOT rely on env vars
# exported here — they do not propagate back to the parent shell.
_nixinstall_generate_encryption_secrets() {
    local use_password use_key password_auto password_length use_key_auto key_length
    local runtime_secrets

    use_password=$(nds_config_get "disk" "ENCRYPTION_PASSWORD")
    use_key=$(nds_config_get "disk" "ENCRYPTION_KEY")
    password_auto=$(nds_config_get "disk" "ENCRYPTION_PASSWORD_AUTO")
    password_length=$(nds_config_get "disk" "ENCRYPTION_PASSWORD_LENGTH")
    use_key_auto=$(nds_config_get "disk" "ENCRYPTION_KEY_AUTO")
    key_length=$(nds_config_get "disk" "ENCRYPTION_KEY_LENGTH")

    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"
    mkdir -p "$runtime_secrets"

    if [[ "$use_password" == "true" ]]; then
        local passphrase
        if [[ "$password_auto" == "true" ]]; then
            log "Generating password (openssl rand, $password_length bytes)"
            passphrase=$(openssl rand -hex "$password_length")
        else
            local pw1="" pw2=""
            while true; do
                printf 'Enter LUKS password: ' > /dev/tty
                read -rs pw1 < /dev/tty; printf '\n' > /dev/tty
                printf 'Confirm LUKS password: ' > /dev/tty
                read -rs pw2 < /dev/tty; printf '\n' > /dev/tty
                if [[ -z "$pw1" ]]; then
                    printf 'Password cannot be empty — try again.\n' > /dev/tty; continue
                fi
                if [[ "$pw1" != "$pw2" ]]; then
                    printf 'Passwords do not match — try again.\n' > /dev/tty; continue
                fi
                if [[ ${#pw1} -lt 12 ]]; then
                    printf 'Password is short (%s chars) — consider a longer one.\n' "${#pw1}" > /dev/tty
                    printf 'Use this password anyway? [y/N]: ' > /dev/tty
                    local confirm
                    read -r confirm < /dev/tty
                    [[ "${confirm,,}" == "y" ]] || continue
                fi
                break
            done
            passphrase="$pw1"
        fi

        printf '%s' "$passphrase" > "$runtime_secrets/luks_password.txt"
        chmod 600 "$runtime_secrets/luks_password.txt"
        nds_install_log "Generated LUKS password (saved to secrets/luks_password.txt)"
    fi

    if [[ "$use_key" == "true" ]]; then
        local keyfile_path="$runtime_secrets/luks_key.bin"
        if [[ "$use_key_auto" == "true" ]]; then
            log "Generating keyfile (openssl rand, $key_length bytes)"
            openssl rand -raw "$key_length" > "$keyfile_path" || return 1
        else
            local src_path
            while true; do
                printf 'Enter path to existing keyfile on the live system: ' > /dev/tty
                read -r src_path < /dev/tty
                if [[ -n "$src_path" && -f "$src_path" ]]; then
                    break
                fi
                printf 'File not found: %s — try again.\n' "$src_path" > /dev/tty
            done
            cp "$src_path" "$keyfile_path"
        fi
        chmod 600 "$keyfile_path"
        nds_install_log "Generated LUKS keyfile (saved to secrets/luks_key.bin)"
    fi

    return 0
}

# Description: Format a partition as LUKS2 using the pre-generated secrets
# (read from the runtime secrets dir, so this works across nds_step_exec
# subshell boundaries), add a second slot if both password and key are
# present, open it, and create the root filesystem on the mapped device.
# Always LUKS2 + Argon2id (cryptsetup defaults).
# Usage: _nixinstall_format_luks "partition"
_nixinstall_format_luks() {
    local partition="$1"
    local use_password use_key runtime_secrets

    use_password=$(nds_config_get "disk" "ENCRYPTION_PASSWORD")
    use_key=$(nds_config_get "disk" "ENCRYPTION_KEY")
    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    log "Formatting LUKS2 on $partition"
    wipefs -a "$partition" 2>/dev/null || true

    local passphrase="" keyfile_path=""
    [[ "$use_password" == "true" ]] && passphrase=$(<"${runtime_secrets}/luks_password.txt")
    [[ "$use_key" == "true" ]] && keyfile_path="${runtime_secrets}/luks_key.bin"

    if [[ "$use_password" == "true" && "$use_key" == "true" ]]; then
        # Both: password as slot 0, keyfile as slot 1
        log "Formatting with password (slot 0) + keyfile (slot 1)"
        printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
        printf '%s' "$passphrase" | cryptsetup open "$partition" cryptroot - || return 1
        printf '%s' "$passphrase" | cryptsetup luksAddKey "$partition" "$keyfile_path" - || return 1
    elif [[ "$use_password" == "true" ]]; then
        log "Formatting with password (slot 0)"
        printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
        printf '%s' "$passphrase" | cryptsetup open "$partition" cryptroot - || return 1
    elif [[ "$use_key" == "true" ]]; then
        log "Formatting with keyfile (slot 0)"
        cryptsetup luksFormat --type luks2 "$partition" "$keyfile_path" || return 1
        cryptsetup open "$partition" cryptroot "$keyfile_path" || return 1
    else
        error "No unlock method configured — cannot format LUKS"
        return 1
    fi

    mkfs.ext4 -L nixos /dev/mapper/cryptroot || return 1
    nds_install_log "LUKS2 formatted on $partition; root fs created"
    return 0
}
