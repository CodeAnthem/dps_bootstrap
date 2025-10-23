#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-22
# Description:   Script Library File
# Feature:       Disk configuration module (partitioning, encryption, swap)
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
disk_init_callback() {
    # MODULE_CONTEXT is already set to "disk"
    
    field_declare DISK_TARGET \
        display="Target Disk" \
        input=disk \
        default="/dev/sda" \
        required=true
    
    field_declare ROOT_SIZE \
        display="Root Partition Size" \
        input=disk_size \
        default="50G" \
        required=true
    
    field_declare ENCRYPTION \
        display="Enable Encryption" \
        input=toggle \
        default=true \
        required=true
    
    field_declare ENCRYPTION_KEY_METHOD \
        display="Encryption Key Method" \
        input=choice \
        default="urandom" \
        options="urandom|openssl|manual"
    
    field_declare ENCRYPTION_KEY_LENGTH \
        display="Encryption Key Length" \
        input=int \
        default="64" \
        min=32 \
        max=512
    
    field_declare ENCRYPTION_USE_PASSPHRASE \
        display="Use Passphrase" \
        input=question \
        default=no
    
    field_declare ENCRYPTION_PASSPHRASE_METHOD \
        display="Passphrase Generation Method" \
        input=choice \
        default="urandom" \
        options="urandom|openssl|manual"
    
    field_declare ENCRYPTION_PASSPHRASE_LENGTH \
        display="Passphrase Length" \
        input=int \
        default="32" \
        min=16 \
        max=128
    
    field_declare PARTITION_SCHEME \
        display="Partition Scheme" \
        input=choice \
        default="auto" \
        options="auto|manual"
    
    field_declare SWAP_SIZE \
        display="Swap Size" \
        input=disk_size \
        default="8G"
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
