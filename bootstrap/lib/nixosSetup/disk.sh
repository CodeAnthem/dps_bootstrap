#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Disk partitioning and encryption setup functions
# ==================================================================================================

# =============================================================================
# ENCRYPTION SETUP FUNCTIONS
# =============================================================================

# Setup encryption for deployment
# Usage: setup_encryption
setup_encryption() {
    echo
    echo "=== Encryption Configuration ==="
    
    local key_length="${DPS_DISK_ENCRYPTION_KEY_LENGTH:-64}"
    local use_passphrase="${DPS_DISK_ENCRYPTION_USE_PASSPHRASE:-n}"
    
    log "Setting up encryption with key length: $key_length bytes"
    
    if [[ ! "$key_length" =~ ^[1-9][0-9]*$ ]] || [[ "$key_length" -lt 16 ]] || [[ "$key_length" -gt 128 ]]; then
        error "Key length must be between 16 and 128 bytes"
    fi
    
    # Passphrase handling
    local passphrase=""
    if [[ "$use_passphrase" == "y" ]]; then
        passphrase=$(prompt_password "Enter passphrase")
    fi
    
    # Generate key using crypto.sh function
    log "Generating encryption key"
    local encryption_key
    encryption_key=$(generate_key_hex "$key_length")
    
    # Apply passphrase if provided
    if [[ -n "$passphrase" ]]; then
        encryption_key=$(echo -n "$encryption_key" | openssl dgst -sha256 -binary | xxd -p -c 256)
    fi
    
    # Save to runtime directory
    local key_file="$RUNTIME_DIR/encryption-key.txt"
    echo "$encryption_key" > "$key_file"
    chmod 600 "$key_file"
    
    echo
    echo "=== CRITICAL: BACKUP THIS ENCRYPTION KEY ==="
    echo "Key: $encryption_key"
    echo "Saved to: $key_file"
    echo "Length: ${key_length} bytes"
    if [[ -n "$passphrase" ]]; then
        echo "Passphrase: [PROTECTED]"
    fi
    echo "=============================================="
    echo
    
    prompt_yes_no "Have you backed up the encryption key?" || error "Please backup the encryption key before continuing"
    
    export DPS_ENCRYPTION_KEY="$encryption_key"
    export DPS_KEY_FILE="$key_file"
}

# =============================================================================
# DISK PARTITIONING FUNCTIONS
# =============================================================================

# Partition disk
# Usage: partition_disk "use_encryption" ["disk_target"]
partition_disk() {
    local use_encryption="$1"
    local disk="${2:-${DPS_DISK_TARGET:-/dev/sda}}"
    
    # Check if disk exists
    if [[ ! -b "$disk" ]]; then
        error "Target disk does not exist: $disk"
    fi
    
    log "Partitioning disk: $disk"
    
    # Create partition table
    parted "$disk" --script -- mklabel gpt
    parted "$disk" --script -- mkpart ESP fat32 1MiB 512MiB
    parted "$disk" --script -- set 1 esp on
    parted "$disk" --script -- mkpart primary 512MiB 100%
    
    # Format boot partition
    mkfs.fat -F 32 -n boot "${disk}1"
    
    if [[ "$use_encryption" == "y" ]]; then
        setup_encrypted_root "${disk}2"
    else
        setup_standard_root "${disk}2"
    fi
}

# Setup encrypted root partition
# Usage: setup_encrypted_root "partition"
setup_encrypted_root() {
    local partition="$1"
    
    log "Setting up encrypted root partition"
    
    if [[ -z "${DPS_ENCRYPTION_KEY:-}" ]]; then
        error "Encryption key not available"
    fi
    
    # Setup LUKS
    echo -n "$DPS_ENCRYPTION_KEY" | cryptsetup luksFormat --type luks2 "$partition" -
    echo -n "$DPS_ENCRYPTION_KEY" | cryptsetup open "$partition" cryptroot -
    
    # Format encrypted partition
    mkfs.ext4 -L nixos /dev/mapper/cryptroot
}

# Setup standard root partition
# Usage: setup_standard_root "partition"
setup_standard_root() {
    local partition="$1"
    
    log "Setting up standard root partition"
    mkfs.ext4 -L nixos "$partition"
}

# =============================================================================
# FILESYSTEM MOUNTING FUNCTIONS
# =============================================================================

# Mount filesystems
# Usage: mount_filesystems "use_encryption"
mount_filesystems() {
    local use_encryption="$1"
    
    log "Mounting filesystems"
    
    if [[ "$use_encryption" == "y" ]]; then
        mount /dev/mapper/cryptroot /mnt
    else
        mount /dev/disk/by-label/nixos /mnt
    fi
    
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
}
