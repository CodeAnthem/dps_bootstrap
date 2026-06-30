#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   LUKS encryption setup for NixOS installation
# Feature:       Encryption key generation, LUKS setup
# ==================================================================================================

# =============================================================================
# ENCRYPTION SETUP
# =============================================================================

# Setup encryption for installation
# Usage: _nixinstall_setup_encryption
_nixinstall_setup_encryption() {
    local key_method key_length use_passphrase
    key_method=$(nds_config_get "disk" "ENCRYPTION_KEY_METHOD")
    key_length=$(nds_config_get "disk" "ENCRYPTION_KEY_LENGTH")
    use_passphrase=$(nds_config_get "disk" "ENCRYPTION_USE_PASSPHRASE")
    
    log "Generating encryption key (method: $key_method, length: $key_length bytes)"
    
    # Generate encryption key based on method
    local encryption_key
    case "$key_method" in
        "urandom")
            encryption_key=$(dd if=/dev/urandom bs=1 count="$key_length" 2>/dev/null | xxd -p -c "$key_length")
            ;;
        "openssl")
            encryption_key=$(openssl rand -hex "$key_length")
            ;;
        "manual")
            read -rsp "Enter encryption key (hex, $key_length bytes): " encryption_key
            echo >&2
            ;;
        *)
            error "Unknown encryption key method: $key_method"
            ;;
    esac
    
    # Apply passphrase if enabled
    if [[ "$use_passphrase" == "true" ]]; then
        local passphrase_method
        passphrase_method=$(nds_config_get "disk" "ENCRYPTION_PASSPHRASE_METHOD")
        
        local passphrase
        if [[ "$passphrase_method" == "manual" ]]; then
            read -rsp "Enter passphrase for encryption key: " passphrase
            echo >&2
        else
            local passphrase_length
            passphrase_length=$(nds_config_get "disk" "ENCRYPTION_PASSPHRASE_LENGTH")
            passphrase=$(openssl rand -base64 "$passphrase_length")
        fi
        
        # Hash key + passphrase together
        encryption_key=$(echo -n "${encryption_key}${passphrase}" | openssl dgst -sha256 -hex | cut -d' ' -f2)
    fi
    
    # Save to runtime directory (no trailing newline — must match the bytes
    # passed to cryptsetup luksFormat so the keyfile is directly usable).
    local runtime_dir="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}"
    mkdir -p "$runtime_dir/secrets"
    local key_file="${runtime_dir}/secrets/luks_key.txt"
    printf '%s' "$encryption_key" > "$key_file"
    chmod 600 "$key_file"
    
    # Export for use by other functions
    export NDS_ENCRYPTION_KEY="$encryption_key"
    export NDS_KEY_FILE="$key_file"

    log "Encryption key saved to $key_file (bundle will be offered after disk setup)"
    
    return 0
}

# Setup encrypted partition
# Usage: _nixinstall_setup_luks_partition "partition"
_nixinstall_setup_luks_partition() {
    local partition="$1"

    if [[ -z "${NDS_ENCRYPTION_KEY:-}" ]]; then
        if [[ -n "${NDS_KEY_FILE:-}" && -f "$NDS_KEY_FILE" ]]; then
            NDS_ENCRYPTION_KEY=$(<"$NDS_KEY_FILE")
            export NDS_ENCRYPTION_KEY
        elif [[ -f "${NDS_RUNTIME_DIR:-}/secrets/luks_key.txt" ]]; then
            NDS_ENCRYPTION_KEY=$(<"${NDS_RUNTIME_DIR}/secrets/luks_key.txt")
            export NDS_ENCRYPTION_KEY
            export NDS_KEY_FILE="${NDS_RUNTIME_DIR}/secrets/luks_key.txt"
        fi
    fi

    if [[ -z "${NDS_ENCRYPTION_KEY:-}" ]]; then
        error "Encryption key not available - run _nixinstall_setup_encryption first"
    fi
    
    log "Setting up LUKS encryption on $partition"

    wipefs -a "$partition" 2>/dev/null || true

    # Setup LUKS
    echo -n "$NDS_ENCRYPTION_KEY" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
    echo -n "$NDS_ENCRYPTION_KEY" | cryptsetup open "$partition" cryptroot - || return 1
    
    # Format encrypted partition
    mkfs.ext4 -L nixos /dev/mapper/cryptroot || return 1
    
    return 0
}
