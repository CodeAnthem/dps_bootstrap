#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-27
# Description:   Disk Module - Configuration
# Feature:       Disk partitioning, encryption, swap configuration
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
disk_init() {
    # Set preset metadata
    nds_configurator_preset_set_display "disk" "Disk"
    nds_configurator_preset_set_priority "disk" 20
    
    # Auto-detect first disk if not provided
    local first_disk=""
    first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)
    
    nds_configurator_var_declare DISK_TARGET \
        display="Target Disk" \
        input=disk \
        default="$first_disk" \
        required=true
    
    nds_configurator_var_declare ENCRYPTION \
        display="Enable Encryption" \
        input=toggle \
        default=true \
        required=true
    
    nds_configurator_var_declare ENCRYPTION_KEY_METHOD \
        display="Encryption Key Method" \
        input=choice \
        default="urandom" \
        options="urandom|openssl|manual"
    
    nds_configurator_var_declare ENCRYPTION_KEY_LENGTH \
        display="Encryption Key Length" \
        input=int \
        default="64" \
        min=32 \
        max=512
    
    nds_configurator_var_declare ENCRYPTION_USE_PASSPHRASE \
        display="Use Passphrase" \
        input=toggle \
        default=false
    
    nds_configurator_var_declare ENCRYPTION_PASSPHRASE_METHOD \
        display="Passphrase Generation Method" \
        input=choice \
        default="urandom" \
        options="urandom|openssl|manual"
    
    nds_configurator_var_declare ENCRYPTION_PASSPHRASE_LENGTH \
        display="Passphrase Length" \
        input=int \
        default="32" \
        min=16 \
        max=512
    
    # Partition strategy: fast (manual tools) or disko (template/user file)
    nds_configurator_var_declare PARTITION_STRATEGY \
        display="Partition Strategy" \
        input=choice \
        default="fast" \
        options="fast|disko"

    # Auto-approve destructive purge without additional prompt (guarded in code too)
    nds_configurator_var_declare AUTO_APPROVE_DISK_PURGE \
        display="Auto-approve Disk Purge" \
        input=toggle \
        default=false

    # Filesystem and layout knobs (fast path supports btrfs/ext4, simple options)
    nds_configurator_var_declare FS_TYPE \
        display="Filesystem Type" \
        input=choice \
        default="btrfs" \
        options="btrfs|ext4"

    nds_configurator_var_declare SWAP_SIZE_MIB \
        display="Swap Size (MiB)" \
        input=int \
        default="0" \
        min=0 

    nds_configurator_var_declare SEPARATE_HOME \
        display="Separate /home" \
        input=toggle \
        default=false

    nds_configurator_var_declare HOME_SIZE \
        display="/home Size (if separate)" \
        input=string \
        default="20G"

    # Unlock mode (partitioning only needs to know if dropbear influences /boot encryption)
    nds_configurator_var_declare ENCRYPTION_UNLOCK_MODE \
        display="Encryption Unlock Mode" \
        input=choice \
        default="manual" \
        options="manual|dropbear|tpm|keyfile"

    # Disko user file path (disables other disk options when provided)
    nds_configurator_var_declare DISKO_USER_FILE \
        display="Disko File (override)" \
        input=path \
        default=""
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
disk_get_active() {
    local encryption use_passphrase strategy user_file separate_home
    
    encryption=$(nds_configurator_config_get "ENCRYPTION")
    use_passphrase=$(nds_configurator_config_get "ENCRYPTION_USE_PASSPHRASE")
    strategy=$(nds_configurator_config_get "PARTITION_STRATEGY")
    user_file=$(nds_configurator_config_get "DISKO_USER_FILE")
    separate_home=$(nds_configurator_config_get "SEPARATE_HOME")
    
    # Base fields always active
    echo "DISK_TARGET"
    echo "ENCRYPTION"
    echo "PARTITION_STRATEGY"
    echo "AUTO_APPROVE_DISK_PURGE"

    # If disko user file provided, lock down other disk options
    if [[ -n "$user_file" ]]; then
        echo "DISKO_USER_FILE"
        return 0
    fi

    echo "FS_TYPE"
    echo "SWAP_SIZE_MIB"
    echo "SEPARATE_HOME"
    [[ "$SEPARATE_HOME" == "true" ]] && echo "HOME_SIZE"
    
    # Fast vs Disko option exposure
    [[ "$strategy" != "fast" ]] && echo "DISKO_USER_FILE"
    
    # Encryption settings only if encryption enabled (toggle normalizes to "true")
    if [[ "$encryption" == "true" ]]; then
        echo "ENCRYPTION_KEY_METHOD"
        echo "ENCRYPTION_KEY_LENGTH"
        echo "ENCRYPTION_USE_PASSPHRASE"
        echo "ENCRYPTION_UNLOCK_MODE"
        
        # Passphrase settings only if passphrase enabled (toggle normalizes to "true")
        if [[ "$use_passphrase" == "true" ]]; then
            echo "ENCRYPTION_PASSPHRASE_METHOD"
            echo "ENCRYPTION_PASSPHRASE_LENGTH"
        fi
    fi
}

# =============================================================================
# CONFIGURATION - Cross-Field Validation
# =============================================================================
# disk_validate_extra() {
#     # No cross-field validation needed for disk module
#     return 0
# }

