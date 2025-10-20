#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Disk Configuration Module
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-20 | Modified: 2025-10-20
# Description:   Smart disk configuration with partition, encryption, and disk selection
# Feature:       Disk detection, partition schemes, encryption options, validation
# Author:        DPS Project
# ==================================================================================================

# Disable nounset for this module - associative arrays don't work well with set -u
set +u

# =============================================================================
# DISK CONFIGURATION STORAGE
# =============================================================================
# Declare as global to ensure persistence across function calls
declare -gA DISK_CONFIG 2>/dev/null || true

# =============================================================================
# DISK CONFIGURATION FUNCTIONS
# =============================================================================
# Initialize disk configuration with smart defaults
# Usage: disk_config_init "actionName"
disk_config_init() {
    local action_name="$1"
    
    # Clear existing disk config for this action
    for key in $(disk_config_get_keys "$action_name" 2>/dev/null || true); do
        local clear_key="${action_name}__${key}"
        unset "DISK_CONFIG[$clear_key]"
    done
    
    # Define disk configuration with defaults
    local disk_configs=(
        "DISK_TARGET:/dev/sda"
        "ENCRYPTION:y|n"
        "ENCRYPTION_KEY_METHOD:auto|manual"
        "ENCRYPTION_KEY_LENGTH:512"
        "ENCRYPTION_PASSPHRASE:auto|manual|none"
        "ENCRYPTION_PASSPHRASE_LENGTH:32"
        "PARTITION_SCHEME:auto|manual"
        "SWAP_SIZE:8G"
        "ROOT_SIZE:*"
    )
    
    # Initialize each disk configuration
    for config_pair in "${disk_configs[@]}"; do
        local key="${config_pair%%:*}"
        local value_with_options="${config_pair#*:}"
        
        # Parse options if they exist
        local default_value="${value_with_options%%|*}"
        local options=""
        if [[ "$value_with_options" == *"|"* ]]; then
            options="${value_with_options#*|}"
        fi
        
        # Store the configuration
        local value_key="${action_name}__${key}__value"
        local options_key="${action_name}__${key}__options"
        DISK_CONFIG[$value_key]="$default_value"
        DISK_CONFIG[$options_key]="$options"
        
        # Check if environment variable exists and override (with DPS_ prefix)
        local env_var_name="DPS_${key}"
        if [[ -n "${!env_var_name:-}" ]]; then
            local env_value="${!env_var_name}"
            DISK_CONFIG[$value_key]="$env_value"
            debug "Disk config override from environment: $env_var_name=$env_value"
        fi
    done
    
    debug "Disk configuration initialized for action: $action_name"
}

# Get disk configuration value
# Usage: disk_config_get "actionName" "KEY"
disk_config_get() {
    local action_name="$1"
    local key="$2"
    local get_key="${action_name}__${key}__value"
    echo "${DISK_CONFIG[$get_key]:-}"
}

# Set disk configuration value
# Usage: disk_config_set "actionName" "KEY" "value"
disk_config_set() {
    local action_name="$1"
    local key="$2"
    local value="$3"
    local set_key="${action_name}__${key}__value"
    DISK_CONFIG[$set_key]="$value"
}

# Get all disk configuration keys
# Usage: disk_config_get_keys "actionName"
disk_config_get_keys() {
    local action_name="$1"
    local prefix="${action_name}__"
    
    for key in "${!DISK_CONFIG[@]}"; do
        if [[ "$key" == "$prefix"*"__value" ]]; then
            local clean_key="${key#$prefix}"
            echo "${clean_key%__value}"
        fi
    done
}

# =============================================================================
# DISK DETECTION AND HELPERS
# =============================================================================
# List available disks
# Usage: list_available_disks
list_available_disks() {
    local disks=()
    
    # Find block devices (excluding partitions, loop devices, etc.)
    while IFS= read -r disk; do
        if [[ -b "$disk" && ! "$disk" =~ [0-9]$ && ! "$disk" =~ loop ]]; then
            local size
            size=$(lsblk -b -d -o SIZE -n "$disk" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
            disks+=("$disk ($size)")
        fi
    done < <(find /dev -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' 2>/dev/null | sort)
    
    printf '%s\n' "${disks[@]}"
}

# Validate disk size format
# Usage: validate_disk_size "8G"
validate_disk_size() {
    local size="$1"
    # Require suffix (G, M, T) or "remaining" or "*" for remaining space
    [[ "$size" =~ ^[0-9]+[GMT]$ || "$size" == "remaining" || "$size" == "*" ]]
}

# =============================================================================
# DISK CONFIGURATION DISPLAY
# =============================================================================
# Display disk configuration
# Usage: disk_config_display "actionName"
disk_config_display() {
    local action_name="$1"
    
    console "Disk Configuration:"
    console "  DISK_TARGET: $(disk_config_get "$action_name" "DISK_TARGET")"
    console "  ENCRYPTION: $(disk_config_get "$action_name" "ENCRYPTION")"
    
    local encryption
    encryption=$(disk_config_get "$action_name" "ENCRYPTION")
    if [[ "$encryption" == "y" ]]; then
        console "  KEY_METHOD: $(disk_config_get "$action_name" "ENCRYPTION_KEY_METHOD")"
        console "  PASSPHRASE: $(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE")"
    fi
    
    console "  PARTITION_SCHEME: $(disk_config_get "$action_name" "PARTITION_SCHEME")"
    
    local scheme
    scheme=$(disk_config_get "$action_name" "PARTITION_SCHEME")
    if [[ "$scheme" == "auto" ]]; then
        local root_size
        root_size=$(disk_config_get "$action_name" "ROOT_SIZE")
        console "  SWAP_SIZE: $(disk_config_get "$action_name" "SWAP_SIZE")"
        console "  ROOT_SIZE: $root_size (remaining disk space)"
    fi
}

# =============================================================================
# DISK CONFIGURATION INTERACTIVE
# =============================================================================
# Interactive disk configuration editing
# Usage: disk_config_interactive "actionName"
disk_config_interactive() {
    local action_name="$1"
    
    console ""
    console "Disk Configuration:"
    
    # Show available disks
    console ""
    console "Available disks:"
    local available_disks
    mapfile -t available_disks < <(list_available_disks)
    for i in "${!available_disks[@]}"; do
        console "  $((i+1))) ${available_disks[i]}"
    done
    console ""
    
    # Disk target configuration
    local disk_target
    disk_target=$(disk_config_get "$action_name" "DISK_TARGET")
    while true; do
        printf "  %-20s [%s]: " "DISK_TARGET" "$disk_target"
        read -r new_disk < /dev/tty
        
        if [[ -n "$new_disk" ]]; then
            # Check if it's a number (selection from list)
            if [[ "$new_disk" =~ ^[0-9]+$ ]] && ((new_disk >= 1 && new_disk <= ${#available_disks[@]})); then
                local selected_disk="${available_disks[$((new_disk-1))]}"
                new_disk="${selected_disk%% *}"  # Extract just the device path
            fi
            
            if [[ -b "$new_disk" ]]; then
                disk_config_set "$action_name" "DISK_TARGET" "$new_disk"
                console "    -> Updated: DISK_TARGET = $new_disk"
                break
            else
                console "    Error: Disk '$new_disk' does not exist or is not a block device"
                continue
            fi
        elif [[ -n "$disk_target" ]]; then
            break
        else
            console "    Error: Disk target is required"
            continue
        fi
    done
    
    # Encryption configuration
    local encryption
    encryption=$(disk_config_get "$action_name" "ENCRYPTION")
    while true; do
        printf "  %-20s [%s] (y/n): " "ENCRYPTION" "$encryption"
        read -r new_encryption < /dev/tty
        
        if [[ -n "$new_encryption" ]]; then
            if [[ "$new_encryption" =~ ^[ynYN]$ ]]; then
                new_encryption="${new_encryption,,}"
                if [[ "$new_encryption" != "$encryption" ]]; then
                    disk_config_set "$action_name" "ENCRYPTION" "$new_encryption"
                    console "    -> Updated: ENCRYPTION = $new_encryption"
                    encryption="$new_encryption"
                else
                    console "    -> Unchanged"
                fi
                break
            else
                console "    Error: Invalid encryption setting. Use 'y' or 'n'"
                continue
            fi
        elif [[ -n "$encryption" ]]; then
            break
        else
            console "    Error: Encryption setting is required"
            continue
        fi
    done
    
    # Encryption settings (only if encryption is enabled)
    if [[ "$encryption" == "y" ]]; then
        console ""
        console "Encryption Settings:"
        
        # Key method
        local key_method
        key_method=$(disk_config_get "$action_name" "ENCRYPTION_KEY_METHOD")
        while true; do
            printf "  %-20s [%s] (auto/manual): " "KEY_METHOD" "$key_method"
            read -r new_key_method < /dev/tty
            
            if [[ -n "$new_key_method" ]]; then
                if [[ "$new_key_method" =~ ^(auto|manual)$ ]]; then
                    if [[ "$new_key_method" != "$key_method" ]]; then
                        disk_config_set "$action_name" "ENCRYPTION_KEY_METHOD" "$new_key_method"
                        console "    -> Updated: KEY_METHOD = $new_key_method"
                        key_method="$new_key_method"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid key method. Use 'auto' or 'manual'"
                    continue
                fi
            elif [[ -n "$key_method" ]]; then
                break
            fi
        done
        
        # Passphrase method
        local passphrase_method
        passphrase_method=$(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE")
        while true; do
            printf "  %-20s [%s] (auto/manual/none): " "PASSPHRASE" "$passphrase_method"
            read -r new_passphrase_method < /dev/tty
            
            if [[ -n "$new_passphrase_method" ]]; then
                if [[ "$new_passphrase_method" =~ ^(auto|manual|none)$ ]]; then
                    if [[ "$new_passphrase_method" != "$passphrase_method" ]]; then
                        disk_config_set "$action_name" "ENCRYPTION_PASSPHRASE" "$new_passphrase_method"
                        console "    -> Updated: PASSPHRASE = $new_passphrase_method"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid passphrase method. Use 'auto', 'manual', or 'none'"
                    continue
                fi
            elif [[ -n "$passphrase_method" ]]; then
                break
            fi
        done
        console ""
    fi
    
    # Partition scheme configuration
    local scheme
    scheme=$(disk_config_get "$action_name" "PARTITION_SCHEME")
    while true; do
        printf "  %-20s [%s] (auto/manual): " "PARTITION_SCHEME" "$scheme"
        read -r new_scheme < /dev/tty
        
        if [[ -n "$new_scheme" ]]; then
            if [[ "$new_scheme" =~ ^(auto|manual)$ ]]; then
                disk_config_set "$action_name" "PARTITION_SCHEME" "$new_scheme"
                console "    -> Updated: PARTITION_SCHEME = $new_scheme"
                scheme="$new_scheme"
                break
            else
                console "    Error: Invalid partition scheme. Use 'auto' or 'manual'"
                continue
            fi
        elif [[ -n "$scheme" ]]; then
            break
        else
            console "    Error: Partition scheme is required"
            continue
        fi
    done
    
    # Auto partition configuration (only if auto scheme)
    if [[ "$scheme" == "auto" ]]; then
        # Swap size
        local swap_size
        swap_size=$(disk_config_get "$action_name" "SWAP_SIZE")
        while true; do
            printf "  %-20s [%s]: " "SWAP_SIZE" "$swap_size"
            read -r new_swap < /dev/tty
            
            if [[ -n "$new_swap" ]]; then
                if validate_disk_size "$new_swap"; then
                    if [[ "$new_swap" != "$swap_size" ]]; then
                        disk_config_set "$action_name" "SWAP_SIZE" "$new_swap"
                        console "    -> Updated: SWAP_SIZE = $new_swap"
                        swap_size="$new_swap"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid size format. Use '8G', '512M', '1T' (suffix required), or '*' for remaining"
                    continue
                fi
            elif [[ -n "$swap_size" ]]; then
                break
            else
                console "    Error: Swap size is required for auto partitioning"
                continue
            fi
        done
        
        # Root size - auto-set to remaining space for auto partitioning
        # Don't prompt user, just set it automatically
        disk_config_set "$action_name" "ROOT_SIZE" "*"
    fi
}

# =============================================================================
# DISK CONFIGURATION VALIDATION
# =============================================================================
# Validate disk configuration
# Usage: disk_config_validate "actionName"
disk_config_validate() {
    local action_name="$1"
    local validation_errors=0
    
    # Validate disk target
    local disk_target
    disk_target=$(disk_config_get "$action_name" "DISK_TARGET")
    if [[ -z "$disk_target" ]]; then
        error "Disk target is required"
        ((validation_errors++))
    elif [[ ! -b "$disk_target" ]]; then
        error "Disk target does not exist or is not a block device: $disk_target"
        ((validation_errors++))
    fi
    
    # Validate encryption setting
    local encryption
    encryption=$(disk_config_get "$action_name" "ENCRYPTION")
    if [[ ! "$encryption" =~ ^[yn]$ ]]; then
        error "Invalid encryption setting: $encryption (must be y or n)"
        ((validation_errors++))
    fi
    
    # Validate partition scheme
    local scheme
    scheme=$(disk_config_get "$action_name" "PARTITION_SCHEME")
    if [[ ! "$scheme" =~ ^(auto|manual)$ ]]; then
        error "Invalid partition scheme: $scheme (must be auto or manual)"
        ((validation_errors++))
    fi
    
    # Validate auto partition settings
    if [[ "$scheme" == "auto" ]]; then
        local swap_size root_size
        swap_size=$(disk_config_get "$action_name" "SWAP_SIZE")
        root_size=$(disk_config_get "$action_name" "ROOT_SIZE")
        
        if [[ -z "$swap_size" ]]; then
            error "Swap size is required for auto partitioning"
            ((validation_errors++))
        elif ! validate_disk_size "$swap_size"; then
            error "Invalid swap size format: $swap_size"
            ((validation_errors++))
        fi
        
        if [[ -z "$root_size" ]]; then
            error "Root size is required for auto partitioning"
            ((validation_errors++))
        elif ! validate_disk_size "$root_size"; then
            error "Invalid root size format: $root_size"
            ((validation_errors++))
        fi
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# =============================================================================
# DISK CONFIGURATION GETTERS
# =============================================================================
# Get DPS variable name for a disk key
# Usage: disk_config_get_var_name "DISK_TARGET"
disk_config_get_var_name() {
    local key="$1"
    echo "DPS_${key}"
}

# Get disk configuration value by key
# Usage: disk_config_get_value "actionName" "DISK_TARGET"
disk_config_get_value() {
    local action_name="$1"
    local key="$2"
    disk_config_get "$action_name" "$key"
}
