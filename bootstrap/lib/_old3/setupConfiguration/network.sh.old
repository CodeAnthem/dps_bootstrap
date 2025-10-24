#!/usr/bin/env bash
# ==================================================================================================
# File:          network.sh
# Description:   Network configuration module (simplified with callbacks)
# Author:        DPS Project
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION CALLBACK
# =============================================================================
network_init_callback() {
    local action="$1"
    local module="$2"
    shift 2
    local config_pairs=("$@")
    
    # Default network configuration
    local defaults=(
        "HOSTNAME:"
        "NETWORK_METHOD:dhcp|static"
        "IP_ADDRESS:"
        "NETWORK_MASK:"
        "NETWORK_GATEWAY:"
        "NETWORK_DNS_PRIMARY:1.1.1.1"
        "NETWORK_DNS_SECONDARY:1.0.0.1"
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
        
        # Check for environment variable override (DPS_KEY format)
        local env_var="DPS_${key}"
        if [[ -n "${!env_var:-}" ]]; then
            config_set "$action" "$module" "$key" "${!env_var}"
            debug "Network config override from environment: $env_var=${!env_var}"
        fi
    done
}

# =============================================================================
# MODULE DISPLAY CALLBACK
# =============================================================================
network_display_callback() {
    local action="$1"
    local module="$2"
    
    console "Network Configuration:"
    console "  HOSTNAME: $(config_get "$action" "$module" "HOSTNAME")"
    
    local method
    method=$(config_get "$action" "$module" "NETWORK_METHOD")
    console "  NETWORK_METHOD: $method"
    
    # Show IP details only if static
    if [[ "$method" == "static" ]]; then
        console "  IP_ADDRESS: $(config_get "$action" "$module" "IP_ADDRESS")"
        console "  NETWORK_MASK: $(config_get "$action" "$module" "NETWORK_MASK")"
        console "  NETWORK_GATEWAY: $(config_get "$action" "$module" "NETWORK_GATEWAY")"
    fi
    
    console "  DNS_PRIMARY: $(config_get "$action" "$module" "NETWORK_DNS_PRIMARY")"
    console "  DNS_SECONDARY: $(config_get "$action" "$module" "NETWORK_DNS_SECONDARY")"
}

# =============================================================================
# MODULE INTERACTIVE CALLBACK
# =============================================================================
network_interactive_callback() {
    local action="$1"
    local module="$2"
    
    console "Network Configuration:"
    
    # Hostname
    local hostname
    hostname=$(config_get "$action" "$module" "HOSTNAME")
    while true; do
        printf "  %-20s [%s]: " "HOSTNAME" "$hostname"
        read -r new_hostname < /dev/tty
        
        if [[ -n "$new_hostname" ]]; then
            if validate_hostname "$new_hostname"; then
                if [[ "$new_hostname" != "$hostname" ]]; then
                    config_set "$action" "$module" "HOSTNAME" "$new_hostname"
                    console "    -> Updated: HOSTNAME = $new_hostname"
                    hostname="$new_hostname"
                else
                    console "    -> Unchanged"
                fi
                break
            else
                console "    Error: Invalid hostname format"
                continue
            fi
        elif [[ -n "$hostname" ]]; then
            break
        else
            console "    Error: Hostname is required"
            continue
        fi
    done
    
    # Network method
    local method
    method=$(config_get "$action" "$module" "NETWORK_METHOD")
    local options
    options=$(config_get_meta "$action" "$module" "NETWORK_METHOD" "options")
    while true; do
        printf "  %-20s [%s] (%s): " "NETWORK_METHOD" "$method" "$options"
        read -r new_method < /dev/tty
        
        if [[ -n "$new_method" ]]; then
            if validate_choice "$new_method" "$options"; then
                if [[ "$new_method" != "$method" ]]; then
                    config_set "$action" "$module" "NETWORK_METHOD" "$new_method"
                    console "    -> Updated: NETWORK_METHOD = $new_method"
                    method="$new_method"
                    
                    # Clear static IP fields if switching to DHCP
                    if [[ "$new_method" == "dhcp" ]]; then
                        config_set "$action" "$module" "IP_ADDRESS" ""
                        config_set "$action" "$module" "NETWORK_MASK" ""
                        config_set "$action" "$module" "NETWORK_GATEWAY" ""
                    fi
                else
                    console "    -> Unchanged"
                fi
                break
            else
                console "    Error: Invalid choice. Choose from: $options"
                continue
            fi
        elif [[ -n "$method" ]]; then
            break
        fi
    done
    
    # Static IP configuration (only if method is static)
    if [[ "$method" == "static" ]]; then
        console ""
        console "Static IP Configuration:"
        
        # IP Address
        local ip
        ip=$(config_get "$action" "$module" "IP_ADDRESS")
        while true; do
            printf "  %-20s [%s]: " "IP_ADDRESS" "$ip"
            read -r new_ip < /dev/tty
            
            if [[ -n "$new_ip" ]]; then
                if validate_ip "$new_ip"; then
                    if [[ "$new_ip" != "$ip" ]]; then
                        config_set "$action" "$module" "IP_ADDRESS" "$new_ip"
                        console "    -> Updated: IP_ADDRESS = $new_ip"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid IP address format"
                    continue
                fi
            elif [[ -n "$ip" ]]; then
                break
            else
                console "    Error: IP address is required for static configuration"
                continue
            fi
        done
        
        # Network Mask
        local mask
        mask=$(config_get "$action" "$module" "NETWORK_MASK")
        while true; do
            printf "  %-20s [%s]: " "NETWORK_MASK" "$mask"
            read -r new_mask < /dev/tty
            
            if [[ -n "$new_mask" ]]; then
                if validate_netmask "$new_mask"; then
                    if [[ "$new_mask" != "$mask" ]]; then
                        config_set "$action" "$module" "NETWORK_MASK" "$new_mask"
                        console "    -> Updated: NETWORK_MASK = $new_mask"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid network mask"
                    continue
                fi
            elif [[ -n "$mask" ]]; then
                break
            else
                console "    Error: Network mask is required for static configuration"
                continue
            fi
        done
        
        # Gateway
        local gateway
        gateway=$(config_get "$action" "$module" "NETWORK_GATEWAY")
        while true; do
            printf "  %-20s [%s]: " "NETWORK_GATEWAY" "$gateway"
            read -r new_gateway < /dev/tty
            
            if [[ -n "$new_gateway" ]]; then
                if validate_ip "$new_gateway"; then
                    if [[ "$new_gateway" != "$gateway" ]]; then
                        config_set "$action" "$module" "NETWORK_GATEWAY" "$new_gateway"
                        console "    -> Updated: NETWORK_GATEWAY = $new_gateway"
                    else
                        console "    -> Unchanged"
                    fi
                    break
                else
                    console "    Error: Invalid gateway IP address"
                    continue
                fi
            elif [[ -n "$gateway" ]]; then
                break
            else
                console "    Error: Gateway is required for static configuration"
                continue
            fi
        done
        console ""
    fi
    
    # DNS Servers (always shown)
    local dns_primary
    dns_primary=$(config_get "$action" "$module" "NETWORK_DNS_PRIMARY")
    printf "  %-20s [%s]: " "DNS_PRIMARY" "$dns_primary"
    read -r new_dns_primary < /dev/tty
    if [[ -n "$new_dns_primary" ]]; then
        if validate_ip "$new_dns_primary"; then
            if [[ "$new_dns_primary" != "$dns_primary" ]]; then
                config_set "$action" "$module" "NETWORK_DNS_PRIMARY" "$new_dns_primary"
                console "    -> Updated: DNS_PRIMARY = $new_dns_primary"
            else
                console "    -> Unchanged"
            fi
        else
            console "    Error: Invalid DNS IP address"
        fi
    fi
    
    local dns_secondary
    dns_secondary=$(config_get "$action" "$module" "NETWORK_DNS_SECONDARY")
    printf "  %-20s [%s]: " "DNS_SECONDARY" "$dns_secondary"
    read -r new_dns_secondary < /dev/tty
    if [[ -n "$new_dns_secondary" ]]; then
        if validate_ip "$new_dns_secondary"; then
            if [[ "$new_dns_secondary" != "$dns_secondary" ]]; then
                config_set "$action" "$module" "NETWORK_DNS_SECONDARY" "$new_dns_secondary"
                console "    -> Updated: DNS_SECONDARY = $new_dns_secondary"
            else
                console "    -> Unchanged"
            fi
        else
            console "    Error: Invalid DNS IP address"
        fi
    fi
    
    console ""
}

# =============================================================================
# FIX ERRORS CALLBACK (only prompt for invalid/missing fields)
# =============================================================================
network_fix_errors_callback() {
    local action="$1"
    local module="$2"
    
    console "Network Configuration:"
    console ""
    
    # Fix hostname if invalid or missing
    local hostname
    hostname=$(config_get "$action" "$module" "HOSTNAME")
    if [[ -z "$hostname" ]] || ! validate_hostname "$hostname"; then
        local new_hostname
        new_hostname=$(prompt_validated "HOSTNAME" "$hostname" "validate_hostname" "required" "Invalid hostname format")
        update_if_changed "$action" "$module" "HOSTNAME" "$hostname" "$new_hostname"
    fi
    
    # Fix network method if invalid or missing
    local method
    method=$(config_get "$action" "$module" "NETWORK_METHOD")
    if [[ -z "$method" ]]; then
        local new_method
        new_method=$(prompt_choice "NETWORK_METHOD" "$method" "dhcp|static")
        update_if_changed "$action" "$module" "NETWORK_METHOD" "$method" "$new_method"
        method="$new_method"
    fi
    
    # Fix static network config if method is static
    if [[ "$method" == "static" ]]; then
        local ip
        ip=$(config_get "$action" "$module" "IP_ADDRESS")
        if [[ -z "$ip" ]] || ! validate_ip "$ip"; then
            local new_ip
            new_ip=$(prompt_validated "IP_ADDRESS" "$ip" "validate_ip" "required" "Invalid IP address")
            update_if_changed "$action" "$module" "IP_ADDRESS" "$ip" "$new_ip"
        fi
        
        local mask
        mask=$(config_get "$action" "$module" "NETWORK_MASK")
        if [[ -z "$mask" ]] || ! validate_netmask "$mask"; then
            local new_mask
            new_mask=$(prompt_validated "NETWORK_MASK" "$mask" "validate_netmask" "required" "Invalid netmask")
            update_if_changed "$action" "$module" "NETWORK_MASK" "$mask" "$new_mask"
        fi
        
        local gateway
        gateway=$(config_get "$action" "$module" "NETWORK_GATEWAY")
        if [[ -z "$gateway" ]] || ! validate_ip "$gateway"; then
            local new_gateway
            new_gateway=$(prompt_validated "NETWORK_GATEWAY" "$gateway" "validate_ip" "required" "Invalid gateway IP")
            update_if_changed "$action" "$module" "NETWORK_GATEWAY" "$gateway" "$new_gateway"
        fi
    fi
    
    console ""
}

# =============================================================================
# MODULE VALIDATION CALLBACK
# =============================================================================
network_validate_callback() {
    local action="$1"
    local module="$2"
    local validation_errors=0
    
    # Validate hostname
    local hostname
    hostname=$(config_get "$action" "$module" "HOSTNAME")
    if [[ -z "$hostname" ]]; then
        validation_error "Hostname is required"
        ((validation_errors++))
    elif ! validate_hostname "$hostname"; then
        validation_error "Invalid hostname format: $hostname"
        ((validation_errors++))
    fi
    
    # Validate network method
    local method
    method=$(config_get "$action" "$module" "NETWORK_METHOD")
    if [[ -z "$method" ]]; then
        validation_error "Network method is required"
        ((validation_errors++))
    fi
    
    # Validate static configuration if method is static
    if [[ "$method" == "static" ]]; then
        local ip
        ip=$(config_get "$action" "$module" "IP_ADDRESS")
        if [[ -z "$ip" ]]; then
            validation_error "IP address is required for static configuration"
            ((validation_errors++))
        elif ! validate_ip "$ip"; then
            validation_error "Invalid IP address: $ip"
            ((validation_errors++))
        fi
        
        local mask
        mask=$(config_get "$action" "$module" "NETWORK_MASK")
        if [[ -z "$mask" ]]; then
            validation_error "Network mask is required for static configuration"
            ((validation_errors++))
        elif ! validate_netmask "$mask"; then
            validation_error "Invalid network mask: $mask"
            ((validation_errors++))
        fi
        
        local gateway
        gateway=$(config_get "$action" "$module" "NETWORK_GATEWAY")
        if [[ -z "$gateway" ]]; then
            validation_error "Gateway is required for static configuration"
            ((validation_errors++))
        elif ! validate_ip "$gateway"; then
            validation_error "Invalid gateway IP: $gateway"
            ((validation_errors++))
        fi
    fi
    
    return "$validation_errors"
}

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
# Register this module with the configurator engine
config_register_module "network" \
    "network_init_callback" \
    "network_display_callback" \
    "network_interactive_callback" \
    "network_validate_callback" \
    "network_fix_errors_callback"
