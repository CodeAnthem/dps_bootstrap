#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-24
# Description:   Script Library File
# Feature:       Network configuration module (hostname, IP, DNS, gateway)
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
network_init_callback() {    
    field_declare HOSTNAME \
        display="Hostname" \
        input=hostname \
        required=true
    
    field_declare NETWORK_METHOD \
        display="Network Method" \
        input=choice \
        default="dhcp" \
        required=true \
        options="dhcp|static"
    
    field_declare NETWORK_IP \
        display="IP Address" \
        required=true \
        input=ip
    
    field_declare NETWORK_MASK \
        display="Network Mask" \
        required=true \
        input=mask \
        default="255.255.255.0"
    
    field_declare NETWORK_GATEWAY \
        display="Gateway" \
        required=true \
        input=ip
    
    field_declare NETWORK_DNS_PRIMARY \
        display="Primary DNS" \
        input=ip \
        required=true \
        default="1.1.1.1"
    
    field_declare NETWORK_DNS_SECONDARY \
        display="Secondary DNS" \
        input=ip \
        required=true \
        default="1.0.0.1"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
network_get_active_fields() {
    local method
    method=$(config_get "network" "NETWORK_METHOD")
    
    # Base fields always active
    echo "HOSTNAME"
    echo "NETWORK_METHOD"
    echo "NETWORK_DNS_PRIMARY"
    echo "NETWORK_DNS_SECONDARY"
    
    # Conditional fields for static configuration
    if [[ "$method" == "static" ]]; then
        echo "NETWORK_IP"
        echo "NETWORK_MASK"
        echo "NETWORK_GATEWAY"
    fi
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Convert IP address to integer
ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

# Validate subnet relationship
# Usage: validate_subnet "192.168.1.10" "255.255.255.0" "192.168.1.1"
validate_subnet() {
    local ip="$1"
    local mask="$2"
    local gateway="$3"
    
    # Convert to integers and check if they're in the same subnet
    local ip_int
    local gateway_int
    local mask_int
    
    ip_int=$(ip_to_int "$ip")
    gateway_int=$(ip_to_int "$gateway")
    mask_int=$(ip_to_int "$mask")
    
    # Apply mask to both IPs and compare
    local ip_network=$((ip_int & mask_int))
    local gateway_network=$((gateway_int & mask_int))
    
    [[ "$ip_network" -eq "$gateway_network" ]]
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
network_validate_extra() {
    local method
    method=$(config_get "network" "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        local ip
        local mask
        local gateway
        
        ip=$(config_get "network" "NETWORK_IP")
        mask=$(config_get "network" "NETWORK_MASK")
        gateway=$(config_get "network" "NETWORK_GATEWAY")
        
        # Check if Gateway is same as IP
        if [[ -n "$ip" && -n "$gateway" && "$ip" == "$gateway" ]]; then
            validation_error "Gateway cannot be the same as IP address"
            return 1
        fi

        # All three must be present for subnet validation
        if [[ -n "$ip" && -n "$mask" && -n "$gateway" ]]; then
            # Validate gateway is in same subnet
            if ! validate_subnet "$ip" "$mask" "$gateway"; then
                validation_error "Gateway $gateway must be in the same subnet as $ip/$mask"
                return 1
            fi
        fi
    fi
    
    return 0
}
