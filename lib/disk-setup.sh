#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Disk Setup Helper Functions
# ==================================================================================================

# =============================================================================
# ENCRYPTION FUNCTIONS
# =============================================================================

generate_encryption_key() {
    local method="$1"
    local length="$2"
    local passphrase="$3"
    
    local key=""
    
    case "$method" in
        "openssl-rand")
            key=$(with_nix_shell "openssl" "openssl rand -base64 '$length'")
            ;;
        "urandom")
            key=$(head -c "$length" /dev/urandom | base64 -w 0)
            ;;
        "manual")
            read -s -p "Enter encryption key: " key
            echo
            ;;
        *)
            error "Unknown encryption method: $method. Valid: openssl-rand, urandom, manual"
            ;;
    esac
    
    if [[ -n "$passphrase" ]]; then
        # Combine key with passphrase using PBKDF2
        key=$(with_nix_shell "openssl" "echo -n '$key' | openssl dgst -sha256 -pbkdf2 -iter 100000 -pass pass:'$passphrase' | cut -d' ' -f2")
    fi
    
    echo "$key"
}

setup_encryption() {
    local use_encryption="$1"
    
    if [[ "$use_encryption" != "y" ]]; then
        return 0
    fi
    
    echo
    echo "=== Encryption Configuration ==="
    
    local key_length="${DPS_DISK_ENCRYPTION_KEY_LENGTH:-32}"
    local method="${DPS_DISK_ENCRYPTION_GENERATE:-urandom}"
    local use_passphrase="${DPS_DISK_ENCRYPTION_USE_PASSPHRASE:-n}"
    
    log "Using encryption method: $method with key length: $key_length bytes"
    
    if [[ ! "$key_length" =~ ^[1-9][0-9]*$ ]] || [[ "$key_length" -lt 16 ]] || [[ "$key_length" -gt 128 ]]; then
        error "Key length must be between 16 and 128 bytes"
    fi
    
    # Passphrase handling
    local passphrase=""
    if [[ "$use_passphrase" == "y" ]]; then
        passphrase=$(prompt_password "Enter passphrase")
    fi
    
    # Generate key
    log "Generating encryption key"
    local encryption_key
    encryption_key=$(generate_encryption_key "$method" "$key_length" "$passphrase")
    
    # Save to runtime directory
    local key_file="$RUNTIME_DIR/encryption-key.txt"
    echo "$encryption_key" > "$key_file"
    chmod 600 "$key_file"
    
    echo
    echo "=== CRITICAL: BACKUP THIS ENCRYPTION KEY ==="
    echo "Key: $encryption_key"
    echo "Saved to: $key_file"
    echo "Method: $method (${key_length} bytes)"
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

partition_disk() {
    local use_encryption="$1"
    local disk="${DPS_DISK_TARGET:-/dev/sda}"
    
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

setup_standard_root() {
    local partition="$1"
    
    log "Setting up standard root partition"
    mkfs.ext4 -L nixos "$partition"
}

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
