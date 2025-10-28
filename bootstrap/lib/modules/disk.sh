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
disk_init_callback() {
    # Auto-detect first disk if not provided
    local first_disk=""
    first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)
    
    nds_field_declare DISK_TARGET \
        display="Target Disk" \
        input=disk \
        default="$first_disk" \
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
        input=toggle \
        default=false
    
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
        max=512
    
    nds_field_declare PARTITION_SCHEME \
        display="Partition Scheme" \
        input=choice \
        default="auto" \
        options="auto|manual"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
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
    
    # Encryption settings only if encryption enabled (toggle normalizes to "true")
    if [[ "$encryption" == "true" ]]; then
        echo "ENCRYPTION_KEY_METHOD"
        echo "ENCRYPTION_KEY_LENGTH"
        echo "ENCRYPTION_USE_PASSPHRASE"
        
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

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Note: Disk configuration is handled during installation by nixosSetup/disk.sh
# It doesn't generate configuration.nix blocks, but we provide these functions
# for module completeness and potential future use

# Auto-mode: reads from configuration modules
nds_nixcfg_disk_auto() {
    # Disk setup is performed during installation, not in configuration.nix
    # Return success but don't register any config blocks
    return 0
}

# Manual mode: explicit parameters
nds_nixcfg_disk() {
    # Disk setup is performed during installation, not in configuration.nix
    # Return success but don't register any config blocks
    return 0
}
