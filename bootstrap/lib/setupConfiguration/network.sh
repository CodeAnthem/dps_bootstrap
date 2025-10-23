#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-22
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
    
    field_declare IP_ADDRESS \
        display="IP Address" \
        input=ip
    
    field_declare NETWORK_MASK \
        display="Network Mask" \
        input=mask
    
    field_declare NETWORK_GATEWAY \
        display="Gateway" \
        input=ip
    
    field_declare NETWORK_DNS_PRIMARY \
        display="Primary DNS" \
        input=ip \
        default="1.1.1.1"
    
    field_declare NETWORK_DNS_SECONDARY \
        display="Secondary DNS" \
        input=ip \
        default="1.0.0.1"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
network_get_active_fields() {
    local method=$(config_get "NETWORK_METHOD")
    
    # Base fields always active
    echo "HOSTNAME"
    echo "NETWORK_METHOD"
    echo "NETWORK_DNS_PRIMARY"
    echo "NETWORK_DNS_SECONDARY"
    
    # Conditional fields for static configuration
    if [[ "$method" == "static" ]]; then
        echo "IP_ADDRESS"
        echo "NETWORK_MASK"
        echo "NETWORK_GATEWAY"
    fi
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
network_validate_extra() {
    local method=$(config_get "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        local ip=$(config_get "IP_ADDRESS")
        local mask=$(config_get "NETWORK_MASK")
        local gateway=$(config_get "NETWORK_GATEWAY")
        
        # Check if Gateway is same as IP
        if [[ "$ip" == "$gateway" ]]; then
            validation_error "Gateway cannot be the same as IP"
            return 1
        fi

        # All three must be present for static
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
