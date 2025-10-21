#!/usr/bin/env bash
# ==================================================================================================
# File:          validation_disk.sh
# Description:   Disk-related validation functions
# Author:        DPS Project
# ==================================================================================================

# Validate disk path exists
# Usage: validate_disk_path "/dev/sda"
validate_disk_path() {
    local disk_path="$1"
    [[ -b "$disk_path" ]]
}

# Alias for compatibility
validate_disk() {
    validate_disk_path "$@"
}

# Validate disk size format
# Usage: validate_disk_size "8G" [allow_remaining]
validate_disk_size() {
    local size="$1"
    local allow_remaining="${2:-false}"
    
    if [[ "$allow_remaining" == "true" ]]; then
        [[ "$size" =~ ^[0-9]+[GMT]$ || "$size" == "remaining" || "$size" == "*" ]]
    else
        [[ "$size" =~ ^[0-9]+[GMT]$ ]]
    fi
}

# Convert size string to bytes
# Usage: convert_size_to_bytes "8G"
convert_size_to_bytes() {
    local size="$1"
    local num="${size%?}"
    local unit="${size: -1}"
    
    case "$unit" in
        G) echo $((num * 1024 * 1024 * 1024)) ;;
        M) echo $((num * 1024 * 1024)) ;;
        T) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "0" ;;
    esac
}
