#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Disk Selection
# Feature:       Disk selection with device listing (custom prompt)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# DISK INPUT - Custom prompt
# ----------------------------------------------------------------------------------

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

prompt_disk() {
    local display="$1"
    local current="$2"
    
    # Show available disks
    console ""
    console "Available disks:"
    local available_disks
    mapfile -t available_disks < <(list_available_disks)
    
    if [[ ${#available_disks[@]} -eq 0 ]]; then
        console "  No disks found"
    else
        for i in "${!available_disks[@]}"; do
            console "  $((i+1))) ${available_disks[i]}"
        done
    fi
    console ""
    
    while true; do
        printf "  %-20s [%s]: " "$display" "$current" >&2
        read -r value < /dev/tty
        
        # Empty - keep current
        if [[ -z "$value" ]]; then
            return 0
        fi
        
        # Check if it's a number (selection from list)
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= ${#available_disks[@]} )); then
            local selected_disk="${available_disks[$((value-1))]}"
            value="${selected_disk%% *}"
        fi
        
        # Validate
        if validate_disk "$value"; then
            echo "$value"
            return 0
        else
            console "    Error: '$value' is not a valid block device"
        fi
    done
}

validate_disk() {
    local value="$1"
    
    [[ -z "$value" ]] && return 1
    [[ -b "$value" ]] && return 0
    
    return 1
}

error_msg_disk() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "'$value' is not a valid block device"
}
