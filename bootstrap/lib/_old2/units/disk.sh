#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Input Unit - Disk Selection
# Feature:       Specialized prompt and validation for disk/block device selection
# ==================================================================================================

# =============================================================================
# DISK UNIT - Custom prompt with device listing
# =============================================================================

# List available disks for user selection
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

# Validate disk path exists and is a block device
validate_disk_path() {
    [[ -b "$1" ]]
}

# Custom prompt for disk selection with numbered list
prompt_disk() {
    local label="$1"
    local current_value="$2"
    
    # Show available disks
    console ""
    console "Available disks:"
    local available_disks
    mapfile -t available_disks < <(list_available_disks)
    for i in "${!available_disks[@]}"; do
        console "  $((i+1))) ${available_disks[i]}"
    done
    console ""
    
    while true; do
        printf "  %-20s [%s]: " "$label" "$current_value" >&2
        read -r new_value < /dev/tty
        
        # Empty input - keep current
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                echo "$current_value"
                return 0
            else
                console "    Error: $label is required"
                continue
            fi
        fi
        
        # Check if it's a number (selection from list)
        if [[ "$new_value" =~ ^[0-9]+$ ]] && ((new_value >= 1 && new_value <= ${#available_disks[@]})); then
            local selected_disk="${available_disks[$((new_value-1))]}"
            new_value="${selected_disk%% *}"
        fi
        
        # Validate disk path
        if [[ -b "$new_value" ]]; then
            echo "$new_value"
            return 0
        else
            console "    Error: Disk '$new_value' does not exist or is not a block device"
            continue
        fi
    done
}
