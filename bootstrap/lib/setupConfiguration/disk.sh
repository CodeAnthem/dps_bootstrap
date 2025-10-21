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
    
    # Show available disks before prompting
    console ""
    console "Available disks:"
    local disk_count=0
    while IFS= read -r disk_info; do
        ((disk_count++))
        console "  $disk_count) $disk_info"
    done < <(list_available_disks)
    console ""
    
    field_declare DISK_TARGET \
        display="Target Disk" \
        required=true \
        default="/dev/sda" \
        validator=validate_disk_path
    
    field_declare ENCRYPTION \
        display="Enable Encryption" \
        required=true \
        default=y \
        type=bool
    
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
    
    field_declare ENCRYPTION_PASSWORD \
        display="Encryption Password" \
        validator=validate_nonempty \
        error="Encryption password cannot be empty"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
disk_get_active_fields() {
    local scheme=$(config_get "PARTITION_SCHEME")
    local encryption=$(config_get "ENCRYPTION")
    
    # Base fields always active
    echo "DISK_TARGET"
    echo "ENCRYPTION"
    echo "PARTITION_SCHEME"
    
    # Encryption password only if encryption enabled
    if [[ "$encryption" == "y" ]]; then
        echo "ENCRYPTION_PASSWORD"
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
