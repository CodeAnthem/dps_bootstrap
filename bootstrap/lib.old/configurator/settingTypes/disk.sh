#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Disk Selection
# Feature:       Disk selection with device listing (custom prompt)
# ==================================================================================================

_disk_validate() {
    local value="$1"
    
    [[ -z "$value" ]] && return 1
    [[ -b "$value" ]] && return 0
    
    return 1
}

_disk_errorCode() {
    local value="$1"
    echo "'$value' is not a valid block device"
}

_disk_prompt() {
    local display="$1"
    local current="$2"
    local type="$3"
    
    # Helper to list available disks
    local disks=()
    while IFS= read -r disk; do
        if [[ -b "$disk" && ! "$disk" =~ [0-9]$ && ! "$disk" =~ loop ]]; then
            local size
            size=$(lsblk -b -d -o SIZE -n "$disk" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
            disks+=("$disk ($size)")
        fi
    done < <(find /dev -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' 2>/dev/null | sort)
    
    # Show available disks
    console ""
    console "Available disks:"
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        console "  No disks found"
    else
        for i in "${!disks[@]}"; do
            console "  $((i+1))) ${disks[i]}"
        done
    fi
    console ""
    
    while true; do
        printf "  %-20s [%s]: " "$display" "$current" >&2
        read -r value < /dev/tty
        
        # Empty - keep current
        if [[ -z "$value" ]]; then
            echo "$current"
            return 0
        fi
        
        # Check if it's a number (selection from list)
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= ${#disks[@]} )); then
            local selected_disk="${disks[$((value-1))]}"
            value="${selected_disk%% *}"
        fi
        
        # Validate
        if _disk_validate "$value"; then
            echo "$value"
            return 0
        else
            console "    Error: '$value' is not a valid block device"
        fi
    done
}

# Auto-register this settingType
nds_cfg_settingType_register "disk"
