#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Network Configuration Module
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-20 | Modified: 2025-10-20
# Description:   Smart network configuration with conditional fields and validation
# Feature:       DHCP/Static detection, subnet validation, hostname validation, conditional fields
# Author:        DPS Project
# ==================================================================================================

# Disable nounset for this module - associative arrays don't work well with set -u
set +u

# =============================================================================
# NETWORK CONFIGURATION STORAGE
# =============================================================================
# Declare as global to ensure persistence across function calls
declare -gA NETWORK_CONFIG 2>/dev/null || true

# =============================================================================
# NETWORK CONFIGURATION FUNCTIONS
# =============================================================================
# Initialize network configuration with smart defaults
# Usage: network_config_init "actionName"
network_config_init() {
    local action_name="$1"
    
    # Clear existing network config for this action
    for key in $(network_config_get_keys "$action_name" 2>/dev/null || true); do
        local clear_key="${action_name}__${key}"
        unset "NETWORK_CONFIG[$clear_key]"
    done
    
    # Define network configuration with defaults
    local network_configs=(
        "HOSTNAME:"
        "NETWORK_METHOD:dhcp|static"
        "IP_ADDRESS:"
        "NETWORK_MASK:255.255.255.0"
        "NETWORK_GATEWAY:"
        "NETWORK_DNS_PRIMARY:1.1.1.1"
        "NETWORK_DNS_SECONDARY:1.0.0.1"
    )
    
    # Fix hostname default to use action name
    network_configs[0]="HOSTNAME:${action_name}-01"
    
    # Initialize each network configuration
    for config_pair in "${network_configs[@]}"; do
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
        NETWORK_CONFIG[$value_key]="$default_value"
        NETWORK_CONFIG[$options_key]="$options"
        
        # Check if environment variable exists and override (with DPS_ prefix)
        local env_var_name="DPS_${key}"
        if [[ -n "${!env_var_name:-}" ]]; then
            local env_value="${!env_var_name}"
            NETWORK_CONFIG[$value_key]="$env_value"
            debug "Network config override from environment: $env_var_name=$env_value"
        fi
    done
    
    debug "Network configuration initialized for action: $action_name"
    # Debug: show what was stored
    for stored_key in "${!NETWORK_CONFIG[@]}"; do
        debug "  Stored: $stored_key = ${NETWORK_CONFIG[$stored_key]}"
    done
}

# Get network configuration value
# Usage: network_config_get "actionName" "KEY"
network_config_get() {
    local action_name="$1"
    local key="$2"
    local get_key="${action_name}__${key}__value"
    echo "${NETWORK_CONFIG[$get_key]:-}"
}

# Set network configuration value
# Usage: network_config_set "actionName" "KEY" "value"
network_config_set() {
    local action_name="$1"
    local key="$2"
    local value="$3"
    local set_key="${action_name}__${key}__value"
    NETWORK_CONFIG[$set_key]="$value"
    
    # Clear dependent fields when method changes
    if [[ "$key" == "NETWORK_METHOD" ]]; then
        if [[ "$value" == "dhcp" ]]; then
            network_config_set "$action_name" "IP_ADDRESS" ""
            network_config_set "$action_name" "NETWORK_GATEWAY" ""
        fi
    fi
}

# Get all network configuration keys
# Usage: network_config_get_keys "actionName"
network_config_get_keys() {
    local action_name="$1"
    local prefix="${action_name}__"
    
    for key in "${!NETWORK_CONFIG[@]}"; do
        if [[ "$key" == "$prefix"*"__value" ]]; then
            local clean_key="${key#$prefix}"
            echo "${clean_key%__value}"
        fi
    done
}

# =============================================================================
# NETWORK CONFIGURATION DISPLAY
# =============================================================================
# Display network configuration
# Usage: network_config_display "actionName"
network_config_display() {
    local action_name="$1"
    local method
    method=$(network_config_get "$action_name" "NETWORK_METHOD")
    
    console "Network Configuration:"
    console "  HOSTNAME: $(network_config_get "$action_name" "HOSTNAME")"
    console "  NETWORK_METHOD: $method"
    
    if [[ "$method" == "static" ]]; then
        local ip_address network_mask gateway
        ip_address=$(network_config_get "$action_name" "IP_ADDRESS")
        network_mask=$(network_config_get "$action_name" "NETWORK_MASK")
        gateway=$(network_config_get "$action_name" "NETWORK_GATEWAY")
        
        console "  IP_ADDRESS: ${ip_address:-"(required for static)"}"
        console "  NETWORK_MASK: $network_mask"
        console "  NETWORK_GATEWAY: ${gateway:-"(required for static)"}"
    fi
    
    console "  DNS_PRIMARY: $(network_config_get "$action_name" "NETWORK_DNS_PRIMARY")"
    console "  DNS_SECONDARY: $(network_config_get "$action_name" "NETWORK_DNS_SECONDARY")"
}

# =============================================================================
# NETWORK CONFIGURATION INTERACTIVE
# =============================================================================
# Interactive network configuration editing
# Usage: network_config_interactive "actionName"
network_config_interactive() {
    local action_name="$1"
    
    console ""
    console "Network Configuration:"
    
    # Hostname configuration
    local hostname
    hostname=$(network_config_get "$action_name" "HOSTNAME")
    while true; do
        printf "  %-20s [%s]: " "HOSTNAME" "$hostname"
        read -r new_hostname < /dev/tty
        
        if [[ -n "$new_hostname" ]]; then
            if validate_hostname "$new_hostname"; then
                network_config_set "$action_name" "HOSTNAME" "$new_hostname"
                console "    -> Updated: HOSTNAME = $new_hostname"
                break
            else
                console "    Error: Invalid hostname format. Use alphanumeric characters and hyphens only."
                continue
            fi
        elif [[ -n "$hostname" ]]; then
            break
        else
            console "    Error: Hostname is required"
            continue
        fi
    done
    
    # Network method configuration
    local method
    method=$(network_config_get "$action_name" "NETWORK_METHOD")
    while true; do
        printf "  %-20s [%s] (dhcp/static): " "NETWORK_METHOD" "$method"
        read -r new_method < /dev/tty
        
        if [[ -n "$new_method" ]]; then
            if [[ "$new_method" =~ ^(dhcp|static)$ ]]; then
                network_config_set "$action_name" "NETWORK_METHOD" "$new_method"
                console "    -> Updated: NETWORK_METHOD = $new_method"
                method="$new_method"
                break
            else
                console "    Error: Invalid method. Use 'dhcp' or 'static'"
                continue
            fi
        elif [[ -n "$method" ]]; then
            break
        else
            console "    Error: Network method is required"
            continue
        fi
    done
    
    # Static network configuration (only if static method)
    if [[ "$method" == "static" ]]; then
        # IP Address
        local ip_address
        ip_address=$(network_config_get "$action_name" "IP_ADDRESS")
        while true; do
            printf "  %-20s [%s]: " "IP_ADDRESS" "${ip_address:-"(required)"}"
            read -r new_ip < /dev/tty
            
            if [[ -n "$new_ip" ]]; then
                if validate_ip_address "$new_ip"; then
                    network_config_set "$action_name" "IP_ADDRESS" "$new_ip"
                    console "    -> Updated: IP_ADDRESS = $new_ip"
                    break
                else
                    console "    Error: Invalid IP address format"
                    continue
                fi
            elif [[ -n "$ip_address" ]]; then
                break
            else
                console "    Error: IP address is required for static configuration"
                continue
            fi
        done
        
        # Network Mask
        local network_mask
        network_mask=$(network_config_get "$action_name" "NETWORK_MASK")
        while true; do
            printf "  %-20s [%s]: " "NETWORK_MASK" "$network_mask"
            read -r new_mask < /dev/tty
            
            if [[ -n "$new_mask" ]]; then
                if validate_ip_address "$new_mask"; then
                    network_config_set "$action_name" "NETWORK_MASK" "$new_mask"
                    console "    -> Updated: NETWORK_MASK = $new_mask"
                    break
                else
                    console "    Error: Invalid network mask format"
                    continue
                fi
            elif [[ -n "$network_mask" ]]; then
                break
            else
                console "    Error: Network mask is required for static configuration"
                continue
            fi
        done
        
        # Gateway
        local gateway
        gateway=$(network_config_get "$action_name" "NETWORK_GATEWAY")
        while true; do
            printf "  %-20s [%s]: " "NETWORK_GATEWAY" "${gateway:-"(required)"}"
            read -r new_gateway < /dev/tty
            
            if [[ -n "$new_gateway" ]]; then
                if validate_ip_address "$new_gateway"; then
                    network_config_set "$action_name" "NETWORK_GATEWAY" "$new_gateway"
                    console "    -> Updated: NETWORK_GATEWAY = $new_gateway"
                    break
                else
                    console "    Error: Invalid gateway IP address format"
                    continue
                fi
            elif [[ -n "$gateway" ]]; then
                break
            else
                console "    Error: Gateway is required for static configuration"
                continue
            fi
        done
    fi
    
    # DNS Configuration (always shown)
    local dns_primary dns_secondary
    dns_primary=$(network_config_get "$action_name" "NETWORK_DNS_PRIMARY")
    dns_secondary=$(network_config_get "$action_name" "NETWORK_DNS_SECONDARY")
    
    printf "  %-20s [%s]: " "DNS_PRIMARY" "$dns_primary"
    read -r new_dns_primary < /dev/tty
    if [[ -n "$new_dns_primary" ]] && validate_ip_address "$new_dns_primary"; then
        network_config_set "$action_name" "NETWORK_DNS_PRIMARY" "$new_dns_primary"
        console "    -> Updated: DNS_PRIMARY = $new_dns_primary"
    fi
    
    printf "  %-20s [%s]: " "DNS_SECONDARY" "$dns_secondary"
    read -r new_dns_secondary < /dev/tty
    if [[ -n "$new_dns_secondary" ]] && validate_ip_address "$new_dns_secondary"; then
        network_config_set "$action_name" "NETWORK_DNS_SECONDARY" "$new_dns_secondary"
        console "    -> Updated: DNS_SECONDARY = $new_dns_secondary"
    fi
}

# =============================================================================
# NETWORK CONFIGURATION VALIDATION
# =============================================================================
# Validate network configuration
# Usage: network_config_validate "actionName"
network_config_validate() {
    local action_name="$1"
    local validation_errors=0
    
    # Validate hostname
    local hostname
    hostname=$(network_config_get "$action_name" "HOSTNAME")
    if [[ -z "$hostname" ]]; then
        error "Hostname is required"
        ((validation_errors++))
    elif ! validate_hostname "$hostname"; then
        error "Invalid hostname format: $hostname"
        ((validation_errors++))
    fi
    
    # Validate network method
    local method
    method=$(network_config_get "$action_name" "NETWORK_METHOD")
    if [[ ! "$method" =~ ^(dhcp|static)$ ]]; then
        error "Invalid network method: $method (must be dhcp or static)"
        ((validation_errors++))
    fi
    
    # Validate static configuration if needed
    if [[ "$method" == "static" ]]; then
        local ip_address network_mask gateway
        ip_address=$(network_config_get "$action_name" "IP_ADDRESS")
        network_mask=$(network_config_get "$action_name" "NETWORK_MASK")
        gateway=$(network_config_get "$action_name" "NETWORK_GATEWAY")
        
        if [[ -z "$ip_address" ]]; then
            error "IP address is required for static network configuration"
            ((validation_errors++))
        elif ! validate_ip_address "$ip_address"; then
            error "Invalid IP address format: $ip_address"
            ((validation_errors++))
        fi
        
        if [[ -z "$network_mask" ]]; then
            error "Network mask is required for static network configuration"
            ((validation_errors++))
        elif ! validate_ip_address "$network_mask"; then
            error "Invalid network mask format: $network_mask"
            ((validation_errors++))
        fi
        
        if [[ -z "$gateway" ]]; then
            error "Gateway is required for static network configuration"
            ((validation_errors++))
        elif ! validate_ip_address "$gateway"; then
            error "Invalid gateway IP address format: $gateway"
            ((validation_errors++))
        fi
        
        # Subnet validation (basic check)
        if [[ -n "$ip_address" && -n "$gateway" && -n "$network_mask" ]]; then
            if ! validate_subnet "$ip_address" "$gateway" "$network_mask"; then
                console "Warning: IP address and gateway may not be in the same subnet"
            fi
        fi
    fi
    
    # Validate DNS servers
    local dns_primary dns_secondary
    dns_primary=$(network_config_get "$action_name" "NETWORK_DNS_PRIMARY")
    dns_secondary=$(network_config_get "$action_name" "NETWORK_DNS_SECONDARY")
    
    if [[ -n "$dns_primary" ]] && ! validate_ip_address "$dns_primary"; then
        error "Invalid primary DNS server IP: $dns_primary"
        ((validation_errors++))
    fi
    
    if [[ -n "$dns_secondary" ]] && ! validate_ip_address "$dns_secondary"; then
        error "Invalid secondary DNS server IP: $dns_secondary"
        ((validation_errors++))
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# =============================================================================
# NETWORK VALIDATION HELPERS
# =============================================================================
# Basic subnet validation
# Usage: validate_subnet "192.168.1.10" "192.168.1.1" "255.255.255.0"
validate_subnet() {
    local ip="$1"
    local gateway="$2"
    local mask="$3"
    
    # Convert IP addresses to integers for comparison
    local ip_int gateway_int mask_int
    ip_int=$(ip_to_int "$ip")
    gateway_int=$(ip_to_int "$gateway")
    mask_int=$(ip_to_int "$mask")
    
    # Calculate network addresses
    local ip_network=$((ip_int & mask_int))
    local gateway_network=$((gateway_int & mask_int))
    
    # Check if they're in the same network
    [[ $ip_network -eq $gateway_network ]]
}

# Convert IP address to integer
# Usage: ip_to_int "192.168.1.1"
ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo $((a * 256**3 + b * 256**2 + c * 256 + d))
}

# =============================================================================
# NETWORK CONFIGURATION GETTERS
# =============================================================================
# Get DPS variable name for a network key
# Usage: network_config_get_var_name "HOSTNAME"
network_config_get_var_name() {
    local key="$1"
    echo "DPS_${key}"
}

# Get network configuration value by key
# Usage: network_config_get_value "actionName" "HOSTNAME"
network_config_get_value() {
    local action_name="$1"
    local key="$2"
    network_config_get "$action_name" "$key"
}
