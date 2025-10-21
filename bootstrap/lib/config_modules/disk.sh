#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Disk configuration module (callback-based)
# ==================================================================================================

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# List available disks
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
# MODULE INITIALIZATION CALLBACK
# =============================================================================
disk_init_callback() {
    local action="$1"
    local module="$2"
    shift 2
    local config_pairs=("$@")
    
    # Default disk configuration
    local defaults=(
        "DISK_TARGET:/dev/sda"
        "ENCRYPTION:y|y|n"
        "ENCRYPTION_KEY_METHOD:urandom|urandom|openssl|manual"
        "ENCRYPTION_KEY_LENGTH:64"
        "ENCRYPTION_USE_PASSPHRASE:n|y|n"
        "ENCRYPTION_PASSPHRASE_METHOD:urandom|urandom|openssl|manual"
        "ENCRYPTION_PASSPHRASE_LENGTH:32"
        "PARTITION_SCHEME:auto|auto|manual"
        "PARTITION_CONFIG_PATH:"
        "SWAP_SIZE:8G"
    )
    
    # Use provided config or defaults
    if [[ ${#config_pairs[@]} -eq 0 ]]; then
        config_pairs=("${defaults[@]}")
    fi
    
    # Parse and store configuration
    for config_pair in "${config_pairs[@]}"; do
        local key="${config_pair%%:*}"
        local value_with_options="${config_pair#*:}"
        local default_value="${value_with_options%%|*}"
        local options="${value_with_options#*|}"
        
        # Store value
        config_set "$action" "$module" "$key" "$default_value"
        
        # Store options metadata
        if [[ "$options" != "$value_with_options" ]]; then
            config_set_meta "$action" "$module" "$key" "options" "$options"
        fi
        
        # Check for environment variable override
        local env_var="DPS_${key}"
        if [[ -n "${!env_var:-}" ]]; then
            config_set "$action" "$module" "$key" "${!env_var}"
            debug "Disk config override from environment: $env_var=${!env_var}"
        fi
    done
}

# =============================================================================
# MODULE DISPLAY CALLBACK
# =============================================================================
disk_display_callback() {
    local action="$1"
    local module="$2"
    
    console "Disk Configuration:"
    console "  DISK_TARGET: $(config_get "$action" "$module" "DISK_TARGET")"
    console "  ENCRYPTION: $(config_get "$action" "$module" "ENCRYPTION")"
    
    local encryption
    encryption=$(config_get "$action" "$module" "ENCRYPTION")
    if [[ "$encryption" == "y" ]]; then
        console "  KEY_METHOD: $(config_get "$action" "$module" "ENCRYPTION_KEY_METHOD")"
        console "  KEY_LENGTH: $(config_get "$action" "$module" "ENCRYPTION_KEY_LENGTH") bytes"
        
        local use_passphrase
        use_passphrase=$(config_get "$action" "$module" "ENCRYPTION_USE_PASSPHRASE")
        console "  USE_PASSPHRASE: $use_passphrase"
        if [[ "$use_passphrase" == "y" ]]; then
            console "  PASSPHRASE_METHOD: $(config_get "$action" "$module" "ENCRYPTION_PASSPHRASE_METHOD")"
            console "  PASSPHRASE_LENGTH: $(config_get "$action" "$module" "ENCRYPTION_PASSPHRASE_LENGTH") chars"
        fi
    fi
    
    console "  PARTITION_SCHEME: $(config_get "$action" "$module" "PARTITION_SCHEME")"
    
    local scheme
    scheme=$(config_get "$action" "$module" "PARTITION_SCHEME")
    if [[ "$scheme" == "auto" ]]; then
        console "  SWAP_SIZE: $(config_get "$action" "$module" "SWAP_SIZE")"
    elif [[ "$scheme" == "manual" ]]; then
        console "  NIXOS_CONFIG_PATH: $(config_get "$action" "$module" "PARTITION_CONFIG_PATH")"
    fi
}

# =============================================================================
# MODULE INTERACTIVE CALLBACK
# =============================================================================
disk_interactive_callback() {
    local action="$1"
    local module="$2"
    
    console "Disk Configuration:"
    console ""
    console "Available disks:"
    local available_disks
    mapfile -t available_disks < <(list_available_disks)
    for i in "${!available_disks[@]}"; do
        console "  $((i+1))) ${available_disks[i]}"
    done
    console ""
    
    # Disk target
    local disk_target
    disk_target=$(config_get "$action" "$module" "DISK_TARGET")
    while true; do
        printf "  %-20s [%s]: " "DISK_TARGET" "$disk_target"
        read -r new_disk < /dev/tty
        
        if [[ -n "$new_disk" ]]; then
            # Check if it's a number (selection from list)
            if [[ "$new_disk" =~ ^[0-9]+$ ]] && ((new_disk >= 1 && new_disk <= ${#available_disks[@]})); then
                local selected_disk="${available_disks[$((new_disk-1))]}"
                new_disk="${selected_disk%% *}"
            fi
            
            if [[ -b "$new_disk" ]]; then
                if [[ "$new_disk" != "$disk_target" ]]; then
                    config_set "$action" "$module" "DISK_TARGET" "$new_disk"
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
    
    # Encryption (Y/N)
    local encryption
    encryption=$(config_get "$action" "$module" "ENCRYPTION")
    local enc_options
    enc_options=$(config_get_meta "$action" "$module" "ENCRYPTION" "options")
    printf "  %-20s [%s] (%s): " "ENCRYPTION" "$encryption" "$enc_options"
    read -r new_encryption < /dev/tty
    if [[ -n "$new_encryption" ]] && validate_yes_no "$new_encryption"; then
        new_encryption="${new_encryption,,}"
        [[ "$new_encryption" == "yes" ]] && new_encryption="y"
        [[ "$new_encryption" == "no" ]] && new_encryption="n"
        
        if [[ "$new_encryption" != "$encryption" ]]; then
            config_set "$action" "$module" "ENCRYPTION" "$new_encryption"
            console "    -> Updated: ENCRYPTION = $new_encryption"
            encryption="$new_encryption"
        else
            console "    -> Unchanged"
        fi
    fi
    
    # Encryption settings (only if enabled)
    if [[ "$encryption" == "y" ]]; then
        console ""
        console "Encryption Key Settings:"
        
        # Key generation method
        local key_method
        key_method=$(config_get "$action" "$module" "ENCRYPTION_KEY_METHOD")
        local key_options
        key_options=$(config_get_meta "$action" "$module" "ENCRYPTION_KEY_METHOD" "options")
        printf "  %-20s [%s] (%s): " "KEY_METHOD" "$key_method" "$key_options"
        read -r new_key_method < /dev/tty
        if [[ -n "$new_key_method" ]] && validate_choice "$new_key_method" "$key_options"; then
            if [[ "$new_key_method" != "$key_method" ]]; then
                config_set "$action" "$module" "ENCRYPTION_KEY_METHOD" "$new_key_method"
                console "    -> Updated: KEY_METHOD = $new_key_method"
            else
                console "    -> Unchanged"
            fi
        fi
        
        # Key length
        local key_length
        key_length=$(config_get "$action" "$module" "ENCRYPTION_KEY_LENGTH")
        printf "  %-20s [%s] bytes: " "KEY_LENGTH" "$key_length"
        read -r new_key_length < /dev/tty
        if [[ -n "$new_key_length" && "$new_key_length" =~ ^[0-9]+$ ]]; then
            if [[ "$new_key_length" != "$key_length" ]]; then
                config_set "$action" "$module" "ENCRYPTION_KEY_LENGTH" "$new_key_length"
                console "    -> Updated: KEY_LENGTH = $new_key_length"
            else
                console "    -> Unchanged"
            fi
        fi
        
        # Use passphrase (Y/N)
        local use_passphrase
        use_passphrase=$(config_get "$action" "$module" "ENCRYPTION_USE_PASSPHRASE")
        local pass_options
        pass_options=$(config_get_meta "$action" "$module" "ENCRYPTION_USE_PASSPHRASE" "options")
        printf "  %-20s [%s] (%s): " "USE_PASSPHRASE" "$use_passphrase" "$pass_options"
        read -r new_use_passphrase < /dev/tty
        if [[ -n "$new_use_passphrase" ]] && validate_yes_no "$new_use_passphrase"; then
            new_use_passphrase="${new_use_passphrase,,}"
            [[ "$new_use_passphrase" == "yes" ]] && new_use_passphrase="y"
            [[ "$new_use_passphrase" == "no" ]] && new_use_passphrase="n"
            
            if [[ "$new_use_passphrase" != "$use_passphrase" ]]; then
                config_set "$action" "$module" "ENCRYPTION_USE_PASSPHRASE" "$new_use_passphrase"
                console "    -> Updated: USE_PASSPHRASE = $new_use_passphrase"
                use_passphrase="$new_use_passphrase"
            else
                console "    -> Unchanged"
            fi
        fi
        
        # Passphrase settings (only if enabled)
        if [[ "$use_passphrase" == "y" ]]; then
            local pass_method
            pass_method=$(config_get "$action" "$module" "ENCRYPTION_PASSPHRASE_METHOD")
            local pass_method_options
            pass_method_options=$(config_get_meta "$action" "$module" "ENCRYPTION_PASSPHRASE_METHOD" "options")
            printf "  %-20s [%s] (%s): " "PASSPHRASE_METHOD" "$pass_method" "$pass_method_options"
            read -r new_pass_method < /dev/tty
            if [[ -n "$new_pass_method" ]] && validate_choice "$new_pass_method" "$pass_method_options"; then
                if [[ "$new_pass_method" != "$pass_method" ]]; then
                    config_set "$action" "$module" "ENCRYPTION_PASSPHRASE_METHOD" "$new_pass_method"
                    console "    -> Updated: PASSPHRASE_METHOD = $new_pass_method"
                else
                    console "    -> Unchanged"
                fi
            fi
            
            # Passphrase length
            local pass_length
            pass_length=$(config_get "$action" "$module" "ENCRYPTION_PASSPHRASE_LENGTH")
            printf "  %-20s [%s] chars: " "PASSPHRASE_LENGTH" "$pass_length"
            read -r new_pass_length < /dev/tty
            if [[ -n "$new_pass_length" && "$new_pass_length" =~ ^[0-9]+$ ]]; then
                if [[ "$new_pass_length" != "$pass_length" ]]; then
                    config_set "$action" "$module" "ENCRYPTION_PASSPHRASE_LENGTH" "$new_pass_length"
                    console "    -> Updated: PASSPHRASE_LENGTH = $new_pass_length"
                else
                    console "    -> Unchanged"
                fi
            fi
        fi
        console ""
    fi
    
    # Partition scheme
    local scheme
    scheme=$(config_get "$action" "$module" "PARTITION_SCHEME")
    local scheme_options
    scheme_options=$(config_get_meta "$action" "$module" "PARTITION_SCHEME" "options")
    printf "  %-20s [%s] (%s): " "PARTITION_SCHEME" "$scheme" "$scheme_options"
    read -r new_scheme < /dev/tty
    if [[ -n "$new_scheme" ]] && validate_choice "$new_scheme" "$scheme_options"; then
        if [[ "$new_scheme" != "$scheme" ]]; then
            config_set "$action" "$module" "PARTITION_SCHEME" "$new_scheme"
            console "    -> Updated: PARTITION_SCHEME = $new_scheme"
            scheme="$new_scheme"
        else
            console "    -> Unchanged"
        fi
    fi
    
    # Manual partition configuration
    if [[ "$scheme" == "manual" ]]; then
        console ""
        console "For manual partitioning, provide a NixOS disko configuration file path."
        console "See: https://github.com/nix-community/disko"
        console "Leave empty to switch back to auto partitioning."
        
        local nixos_config_path
        nixos_config_path=$(config_get "$action" "$module" "PARTITION_CONFIG_PATH")
        
        while true; do
            printf "  %-20s [%s]: " "NIXOS_CONFIG_PATH" "$nixos_config_path"
            read -r new_nixos_config_path < /dev/tty
            
            if [[ -z "$new_nixos_config_path" ]]; then
                # Empty input - switch to auto
                console "    -> Switching to auto partitioning (no path provided)"
                config_set "$action" "$module" "PARTITION_SCHEME" "auto"
                scheme="auto"
                break
            elif validate_file_path "$new_nixos_config_path"; then
                # Valid file path
                if [[ "$new_nixos_config_path" != "$nixos_config_path" ]]; then
                    config_set "$action" "$module" "PARTITION_CONFIG_PATH" "$new_nixos_config_path"
                    console "    -> Updated: NIXOS_CONFIG_PATH = $new_nixos_config_path"
                else
                    console "    -> Unchanged"
                fi
                break
            else
                console "    Error: File does not exist: $new_nixos_config_path"
                continue
            fi
        done
        console ""
    fi
    
    # Auto partition configuration
    if [[ "$scheme" == "auto" ]]; then
        # Swap size with validation
        local swap_size
        swap_size=$(config_get "$action" "$module" "SWAP_SIZE")
        
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
                        config_set "$action" "$module" "SWAP_SIZE" "$new_swap"
                        console "    -> Updated: SWAP_SIZE = $new_swap"
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
    
    console ""
}

# =============================================================================
# MODULE VALIDATION CALLBACK
# =============================================================================
disk_validate_callback() {
    local action="$1"
    local module="$2"
    local validation_errors=0
    
    # Validate disk target
    local disk_target
    disk_target=$(config_get "$action" "$module" "DISK_TARGET")
    if [[ -z "$disk_target" ]]; then
        error "Disk target is required"
        ((validation_errors++))
    elif ! validate_disk_path "$disk_target"; then
        error "Invalid disk target or disk does not exist: $disk_target"
        ((validation_errors++))
    fi
    
    # Validate encryption
    local encryption
    encryption=$(config_get "$action" "$module" "ENCRYPTION")
    if [[ -z "$encryption" ]]; then
        error "Encryption setting is required"
        ((validation_errors++))
    elif ! validate_yes_no "$encryption"; then
        error "Encryption must be 'y' or 'n'"
        ((validation_errors++))
    fi
    
    # Validate partition scheme
    local scheme
    scheme=$(config_get "$action" "$module" "PARTITION_SCHEME")
    if [[ -z "$scheme" ]]; then
        error "Partition scheme is required"
        ((validation_errors++))
    fi
    
    # Validate auto partitioning configuration
    if [[ "$scheme" == "auto" ]]; then
        local swap_size
        swap_size=$(config_get "$action" "$module" "SWAP_SIZE")
        if [[ -z "$swap_size" ]]; then
            error "Swap size is required for auto partitioning"
            ((validation_errors++))
        elif ! validate_disk_size "$swap_size"; then
            error "Invalid swap size format: $swap_size"
            ((validation_errors++))
        fi
    fi
    
    return "$validation_errors"
}

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
# Register this module with the configurator engine
config_register_module "disk" \
    "disk_init_callback" \
    "disk_display_callback" \
    "disk_interactive_callback" \
    "disk_validate_callback"
