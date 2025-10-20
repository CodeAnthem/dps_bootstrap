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
        "ENCRYPTION:auto|none|manual"
        "ENCRYPTION_KEY_METHOD:urandom|openssl"
        "ENCRYPTION_KEY_LENGTH:32"
        "ENCRYPTION_PASSPHRASE:auto|none|manual"
        "ENCRYPTION_PASSPHRASE_METHOD:urandom|openssl"
        "ENCRYPTION_PASSPHRASE_LENGTH:32"
        "PARTITION_SCHEME:auto|manual"
        "PARTITION_CONFIG_PATH:"
        "SWAP_SIZE:8G"
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
# Usage: validate_disk_size "8G" [allow_remaining]
validate_disk_size() {
    local size="$1"
    local allow_remaining="${2:-false}"
    
    if [[ "$allow_remaining" == "true" ]]; then
        # Allow remaining space markers for root partition
        [[ "$size" =~ ^[0-9]+[GMT]$ || "$size" == "remaining" || "$size" == "*" ]]
    else
        # Only allow specific sizes (for swap)
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
    if [[ "$encryption" == "auto" || "$encryption" == "manual" ]]; then
        if [[ "$encryption" == "auto" ]]; then
            console "  KEY_GEN_METHOD: $(disk_config_get "$action_name" "ENCRYPTION_KEY_METHOD")"
            console "  KEY_LENGTH: $(disk_config_get "$action_name" "ENCRYPTION_KEY_LENGTH")"
        fi
        local passphrase
        passphrase=$(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE")
        console "  PASSPHRASE: $passphrase"
        if [[ "$passphrase" == "auto" ]]; then
            console "  PASS_GEN_METHOD: $(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE_METHOD")"
            console "  PASS_LENGTH: $(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE_LENGTH")"
        fi
    fi
    
    console "  PARTITION_SCHEME: $(disk_config_get "$action_name" "PARTITION_SCHEME")"
    
    local scheme
    scheme=$(disk_config_get "$action_name" "PARTITION_SCHEME")
    if [[ "$scheme" == "auto" ]]; then
        console "  SWAP_SIZE: $(disk_config_get "$action_name" "SWAP_SIZE")"
        console "  ROOT_SIZE: remaining disk space"
    elif [[ "$scheme" == "manual" ]]; then
        console "  NIXOS_CONFIG_PATH: $(disk_config_get "$action_name" "PARTITION_CONFIG_PATH")"
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
                if [[ "$new_disk" != "$disk_target" ]]; then
                    disk_config_set "$action_name" "DISK_TARGET" "$new_disk"
                    console "    -> Updated: DISK_TARGET = $new_disk"
                    disk_target="$new_disk"
                else
                    console "    -> Unchanged"
                fi
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
        printf "  %-20s [%s] (auto/none/manual): " "ENCRYPTION" "$encryption"
        read -r new_encryption < /dev/tty
        
        if [[ -n "$new_encryption" ]]; then
            if [[ "$new_encryption" =~ ^(auto|none|manual)$ ]]; then
                if [[ "$new_encryption" != "$encryption" ]]; then
                    disk_config_set "$action_name" "ENCRYPTION" "$new_encryption"
                    console "    -> Updated: ENCRYPTION = $new_encryption"
                    encryption="$new_encryption"
                else
                    console "    -> Unchanged"
                fi
                break
            else
                console "    Error: Invalid encryption. Use 'auto' (generate), 'none' (disabled), or 'manual' (provide key)"
                continue
            fi
        elif [[ -n "$encryption" ]]; then
            break
        else
            console "    Error: Encryption setting is required"
            continue
        fi
    done
    
    # Encryption key settings (only if auto or manual encryption)
    if [[ "$encryption" == "auto" || "$encryption" == "manual" ]]; then
        console ""
        console "Encryption Key Settings:"
        
        # Key generation method (only for auto)
        if [[ "$encryption" == "auto" ]]; then
            local key_method
            key_method=$(disk_config_get "$action_name" "ENCRYPTION_KEY_METHOD")
            while true; do
                printf "  %-20s [%s] (urandom/openssl): " "KEY_GEN_METHOD" "$key_method"
                read -r new_key_method < /dev/tty
                
                if [[ -n "$new_key_method" ]]; then
                    if [[ "$new_key_method" =~ ^(urandom|openssl)$ ]]; then
                        if [[ "$new_key_method" != "$key_method" ]]; then
                            disk_config_set "$action_name" "ENCRYPTION_KEY_METHOD" "$new_key_method"
                            console "    -> Updated: KEY_GEN_METHOD = $new_key_method"
                        else
                            console "    -> Unchanged"
                        fi
                        break
                    else
                        console "    Error: Invalid method. Use 'urandom' or 'openssl'"
                        continue
                    fi
                elif [[ -n "$key_method" ]]; then
                    break
                fi
            done
            
            # Key length
            local key_length
            key_length=$(disk_config_get "$action_name" "ENCRYPTION_KEY_LENGTH")
            printf "  %-20s [%s]: " "KEY_LENGTH" "$key_length"
            read -r new_key_length < /dev/tty
            if [[ -n "$new_key_length" && "$new_key_length" =~ ^[0-9]+$ ]]; then
                if [[ "$new_key_length" != "$key_length" ]]; then
                    disk_config_set "$action_name" "ENCRYPTION_KEY_LENGTH" "$new_key_length"
                    console "    -> Updated: KEY_LENGTH = $new_key_length"
                else
                    console "    -> Unchanged"
                fi
            fi
        fi
        
        # Passphrase
        local passphrase
        passphrase=$(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE")
        while true; do
            printf "  %-20s [%s] (auto/none/manual): " "PASSPHRASE" "$passphrase"
            read -r new_passphrase < /dev/tty
            
            if [[ -n "$new_passphrase" ]]; then
                if [[ "$new_passphrase" =~ ^(auto|none|manual)$ ]]; then
                    if [[ "$new_passphrase" != "$passphrase" ]]; then
                        disk_config_set "$action_name" "ENCRYPTION_PASSPHRASE" "$new_passphrase"
                        console "    -> Updated: PASSPHRASE = $new_passphrase"
                        passphrase="$new_passphrase"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid passphrase. Use 'auto' (generate), 'none' (no passphrase), or 'manual' (provide)"
                    continue
                fi
            elif [[ -n "$passphrase" ]]; then
                break
            fi
        done
        
        # Passphrase generation settings (only if auto)
        if [[ "$passphrase" == "auto" ]]; then
            local passphrase_method
            passphrase_method=$(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE_METHOD")
            while true; do
                printf "  %-20s [%s] (urandom/openssl): " "PASS_GEN_METHOD" "$passphrase_method"
                read -r new_passphrase_method < /dev/tty
                
                if [[ -n "$new_passphrase_method" ]]; then
                    if [[ "$new_passphrase_method" =~ ^(urandom|openssl)$ ]]; then
                        if [[ "$new_passphrase_method" != "$passphrase_method" ]]; then
                            disk_config_set "$action_name" "ENCRYPTION_PASSPHRASE_METHOD" "$new_passphrase_method"
                            console "    -> Updated: PASS_GEN_METHOD = $new_passphrase_method"
                        else
                            console "    -> Unchanged"
                        fi
                        break
                    else
                        console "    Error: Invalid method. Use 'urandom' or 'openssl'"
                        continue
                    fi
                elif [[ -n "$passphrase_method" ]]; then
                    break
                fi
            done
            
            # Passphrase length
            local passphrase_length
            passphrase_length=$(disk_config_get "$action_name" "ENCRYPTION_PASSPHRASE_LENGTH")
            printf "  %-20s [%s]: " "PASS_LENGTH" "$passphrase_length"
            read -r new_passphrase_length < /dev/tty
            if [[ -n "$new_passphrase_length" && "$new_passphrase_length" =~ ^[0-9]+$ ]]; then
                if [[ "$new_passphrase_length" != "$passphrase_length" ]]; then
                    disk_config_set "$action_name" "ENCRYPTION_PASSPHRASE_LENGTH" "$new_passphrase_length"
                    console "    -> Updated: PASS_LENGTH = $new_passphrase_length"
                else
                    console "    -> Unchanged"
                fi
            fi
        fi
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
    
    # Manual partition configuration (only if manual scheme)
    if [[ "$scheme" == "manual" ]]; then
        console ""
        console "For manual partitioning, provide a NixOS disko configuration file path."
        console "See: https://github.com/nix-community/disko"
        
        # NixOS config path
        local nixos_config_path
        nixos_config_path=$(disk_config_get "$action_name" "PARTITION_CONFIG_PATH")
        printf "  %-20s [%s]: " "NIXOS_CONFIG_PATH" "$nixos_config_path"
        read -r new_nixos_config_path < /dev/tty
        if [[ -n "$new_nixos_config_path" ]]; then
            if [[ "$new_nixos_config_path" != "$nixos_config_path" ]]; then
                disk_config_set "$action_name" "PARTITION_CONFIG_PATH" "$new_nixos_config_path"
                console "    -> Updated: NIXOS_CONFIG_PATH = $new_nixos_config_path"
            else
                console "    -> Unchanged"
            fi
        fi
        console ""
    fi
    
    # Auto partition configuration (only if auto scheme)
    if [[ "$scheme" == "auto" ]]; then
        # Swap size
        local swap_size
        local disk_target
        disk_target=$(disk_config_get "$action_name" "DISK_TARGET")
        swap_size=$(disk_config_get "$action_name" "SWAP_SIZE")
        
        while true; do
            printf "  %-20s [%s]: " "SWAP_SIZE" "$swap_size"
            read -r new_swap < /dev/tty
            
            if [[ -n "$new_swap" ]]; then
                if validate_disk_size "$new_swap"; then
                    # Check if swap is > 20% of disk size
                    local disk_size_bytes
                    disk_size_bytes=$(lsblk -b -d -o SIZE -n "$disk_target" 2>/dev/null || echo "0")
                    local swap_bytes
                    swap_bytes=$(convert_size_to_bytes "$new_swap")
                    
                    if [[ "$disk_size_bytes" -gt 0 && "$swap_bytes" -gt 0 ]]; then
                        local percent=$((swap_bytes * 100 / disk_size_bytes))
                        if [[ "$percent" -gt 20 ]]; then
                            console "    Warning: Swap size is ${percent}% of disk (> 20%). This is unusually large."
                            printf "    Continue anyway? [y/N]: "
                            read -r confirm < /dev/tty
                            if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                                continue
                            fi
                        fi
                    fi
                    
                    if [[ "$new_swap" != "$swap_size" ]]; then
                        disk_config_set "$action_name" "SWAP_SIZE" "$new_swap"
                        console "    -> Updated: SWAP_SIZE = $new_swap"
                        swap_size="$new_swap"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid size format. Use '8G', '512M', '1T' (suffix required)"
                    continue
                fi
            elif [[ -n "$swap_size" ]]; then
                break
            else
                console "    Error: Swap size is required for auto partitioning"
                continue
            fi
        done
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
