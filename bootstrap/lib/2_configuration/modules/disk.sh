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
    
    # Auto-detect first disk if not provided
    local default_disk=""
    if [[ -z "$(nds_config_get "disk" "DISK_TARGET")" ]]; then
        # Source disk input to get list function (if not already loaded)
        if ! type list_available_disks &>/dev/null; then
            source "${LIB_DIR}/1_inputs/disk/disk.sh" 2>/dev/null || true
        fi
        if type list_available_disks &>/dev/null; then
            default_disk=$(list_available_disks | head -n1 | awk '{print $1}')
        fi
    fi
    
    nds_field_declare DISK_TARGET \
        display="Target Disk" \
        input=disk \
        default="$default_disk" \
        required=true
    
    nds_field_declare ENCRYPTION \
        display="Enable Encryption" \
        input=toggle \
        default=true \
        required=true
    
    nds_field_declare ENCRYPTION_KEY_METHOD \
        display="Encryption Key Method" \
        input=choice \
        default="urandom" \
        options="urandom|openssl|manual"
    
    nds_field_declare ENCRYPTION_KEY_LENGTH \
        display="Encryption Key Length" \
        input=int \
        default="64" \
        min=32 \
        max=512
    
    nds_field_declare ENCRYPTION_USE_PASSPHRASE \
        display="Use Passphrase" \
        input=question \
        default=no
    
    nds_field_declare ENCRYPTION_PASSPHRASE_METHOD \
        display="Passphrase Generation Method" \
        input=choice \
        default="urandom" \
        options="urandom|openssl|manual"
    
    nds_field_declare ENCRYPTION_PASSPHRASE_LENGTH \
        display="Passphrase Length" \
        input=int \
        default="32" \
        min=16 \
        max=128
    
    nds_field_declare PARTITION_SCHEME \
        display="Partition Scheme" \
        input=choice \
        default="auto" \
        options="auto|manual"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
disk_get_active_fields() {
    local encryption
    local use_passphrase
    
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    use_passphrase=$(nds_config_get "disk" "ENCRYPTION_USE_PASSPHRASE")
    
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
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
disk_validate_extra() {
    # No cross-field validation needed for disk module
    return 0
}
