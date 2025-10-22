#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-22
# Description:   Script Library File
# Feature:       Disk configuration module (partitioning, encryption, swap)
# ==================================================================================================

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
list_available_disks() {
    local disks=()
    
    while IFS= read -r disk; do
        if [[ -b "$disk" && ! "$disk" =~ [0-9]$ && ! "$disk" =~ loop ]]; then
            local size
            size=$(lsblk -b -d -o SIZE -n "$disk" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
            disks+=("$disk ($size)")
        fi
    done < <(find /dev -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' 2>/dev/null | sort)
    
    printf '%s\n' "${disks[@]}"
}

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
disk_init_callback() {
    # MODULE_CONTEXT is already set to "disk"
    
    field_declare DISK_TARGET \
        display="Target Disk" \
        required=true \
        default="/dev/sda" \
        type=disk
    
    field_declare ENCRYPTION \
        display="Enable Encryption" \
        required=true \
        default=y \
        type=bool
    
    field_declare ENCRYPTION_KEY_METHOD \
        display="Encryption Key Method" \
        default="urandom" \
        type=choice \
        options="urandom|openssl|manual"
    
    field_declare ENCRYPTION_KEY_LENGTH \
        display="Encryption Key Length" \
        default="64" \
        type=number \
        validator=validate_port
    
    field_declare ENCRYPTION_USE_PASSPHRASE \
        display="Use Additional Passphrase" \
        default="n" \
        type=bool
    
    field_declare ENCRYPTION_PASSPHRASE_METHOD \
        display="Passphrase Generation Method" \
        default="urandom" \
        type=choice \
        options="urandom|openssl|manual"
    
    field_declare ENCRYPTION_PASSPHRASE_LENGTH \
        display="Passphrase Length" \
        default="32" \
        type=number \
        validator=validate_port
    
    field_declare PARTITION_SCHEME \
        display="Partition Scheme" \
        required=true \
        default=auto \
        type=choice \
        options="auto|manual"
    
    field_declare SWAP_SIZE \
        display="Swap Size" \
        default="8G" \
        validator=validate_disk_size
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
disk_get_active_fields() {
    local scheme=$(config_get "PARTITION_SCHEME")
    local encryption=$(config_get "ENCRYPTION")
    local use_passphrase=$(config_get "ENCRYPTION_USE_PASSPHRASE")
    
    # Base fields always active
    echo "DISK_TARGET"
    echo "ENCRYPTION"
    echo "PARTITION_SCHEME"
    
    # Encryption settings only if encryption enabled
    if [[ "$encryption" == "y" ]]; then
        echo "ENCRYPTION_KEY_METHOD"
        echo "ENCRYPTION_KEY_LENGTH"
        echo "ENCRYPTION_USE_PASSPHRASE"
        
        # Passphrase settings only if passphrase enabled
        if [[ "$use_passphrase" == "y" ]]; then
            echo "ENCRYPTION_PASSPHRASE_METHOD"
            echo "ENCRYPTION_PASSPHRASE_LENGTH"
        fi
    fi
    
    # Swap size only for auto partitioning
    if [[ "$scheme" == "auto" ]]; then
        echo "SWAP_SIZE"
    fi
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
disk_validate_extra() {
    # No cross-field validation needed for disk module
    return 0
}
