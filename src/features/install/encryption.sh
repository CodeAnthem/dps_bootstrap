#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-02
# Description:   LUKS2 encryption setup for NixOS installation
# Feature:       Password and/or keyfile LUKS slots, /dev/urandom generation
# ==================================================================================================

# =============================================================================
# ENCRYPTION SETUP
# =============================================================================

# Description: Generate exactly N random alphanumeric characters (A-Za-z0-9)
# from /dev/urandom (openssl-free; the NixOS live ISO ships no openssl). A 62
# symbol alphabet gives ~5.95 bits/char, so N=32 is ~190 bits — far stronger
# than the same length in hex. Reads a generous buffer via process
# substitution (no pipe, so `set -o pipefail` cannot trip on SIGPIPE) and
# truncates to N. Alphanumeric only, so it is safe on cryptsetup stdin and in
# shell contexts.
# Usage: _nds_urandom_chars <char_count>
_nds_urandom_chars() {
    nds_install_urandom_chars "$@"
}

# Description: Generate or collect unlock secrets (password and/or keyfile)
# and save them to the runtime secrets directory for the backup bundle and
# for _nixinstall_format_luks to read back. Run before partitioning.
# NOTE: This runs under nds_step_exec (a subshell with stderr -> install log),
# so interactive prompts write to /dev/tty explicitly. Do NOT rely on env vars
# exported here — they do not propagate back to the parent shell.
_nixinstall_generate_encryption_secrets() {
    local use_password use_key password_auto password_length use_key_auto key_length
    local runtime_secrets

    nds_install_ctx_ensure
    use_password="$(nds_install_ctx_get ENCRYPTION_PASSWORD)"
    use_key="$(nds_install_ctx_get ENCRYPTION_KEY)"
    password_auto="$(nds_install_ctx_get ENCRYPTION_PASSWORD_AUTO)"
    password_length="$(nds_install_ctx_get ENCRYPTION_PASSWORD_LENGTH)"
    use_key_auto="$(nds_install_ctx_get ENCRYPTION_KEY_AUTO)"
    key_length="$(nds_install_ctx_get ENCRYPTION_KEY_LENGTH)"

    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"
    mkdir -p "$runtime_secrets" || { error "Cannot create secrets dir"; return 1; }

    if [[ "$use_password" == "true" ]]; then
        local passphrase pw_file="$runtime_secrets/luks_password.txt"
        if [[ "$password_auto" == "true" ]]; then
            log "Generating password (/dev/urandom, $password_length hex chars)"
            passphrase=$(_nds_urandom_chars "$password_length")
            if [[ -z "$passphrase" ]]; then
                error "Password generation from /dev/urandom failed"
                return 1
            fi
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

        printf '%s' "$passphrase" > "$pw_file"
        chmod 600 "$pw_file"
        [[ -s "$pw_file" ]] || { error "Failed to write password file"; return 1; }
        nds_install_log "Generated LUKS password (saved to secrets/luks_password.txt)"
    fi

    if [[ "$use_key" == "true" ]]; then
        local keyfile_path="$runtime_secrets/luks_key.bin"
        if [[ "$use_key_auto" == "true" ]]; then
            log "Generating keyfile (/dev/urandom, $key_length bytes)"
            head -c "$key_length" /dev/urandom > "$keyfile_path" || { error "Keyfile generation failed"; return 1; }
            [[ -s "$keyfile_path" ]] || { error "Keyfile is empty"; return 1; }
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

    nds_install_ctx_ensure
    use_password="${NDS_CTX_ENCRYPTION_PASSWORD}"
    use_key="${NDS_CTX_ENCRYPTION_KEY}"
    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    nds_install_luks_format_partition "$partition" "$use_password" "$use_key" "$runtime_secrets" || return 1
    nds_install_log "LUKS2 formatted on $partition; root fs created"
    return 0
}
