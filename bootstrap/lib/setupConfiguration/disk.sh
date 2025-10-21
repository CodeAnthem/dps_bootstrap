#!/usr/bin/env bash
# ==================================================================================================
# File:          disk.sh
# Description:   Disk configuration module
# Author:        DPS Project
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
        validator=validate_disk_path \
        error="Invalid disk or disk does not exist"
    
    field_declare ENCRYPTION \
        display="Enable Encryption" \
        required=true \
        default=y \
        type=bool \
        validator=validate_yes_no
    
    field_declare PARTITION_SCHEME \
        display="Partition Scheme" \
        required=true \
        default=auto \
        type=choice \
        options="auto|manual" \
        validator=validate_choice
    
    field_declare SWAP_SIZE \
        display="Swap Size" \
        required=false \
        default="8G" \
        validator=validate_disk_size \
        error="Invalid size format (use: 8G, 512M, etc)"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
disk_get_active_fields() {
    local scheme=$(config_get "PARTITION_SCHEME")
    
    # Base fields always active
    echo "DISK_TARGET"
    echo "ENCRYPTION"
    echo "PARTITION_SCHEME"
    
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

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
config_register_module "disk" \
    "disk_init_callback" \
    "disk_get_active_fields"
