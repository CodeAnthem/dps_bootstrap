#!/usr/bin/env bash
# ==================================================================================================
# File:          network.sh
# Description:   Network configuration module
# Author:        DPS Project
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
network_init_callback() {    
    field_declare HOSTNAME \
        display="Hostname" \
        required=true \
        validator=validate_hostname
    
    field_declare NETWORK_METHOD \
        display="Network Method" \
        required=true \
        default=dhcp \
        type=choice \
        options="dhcp|static"
    
    field_declare IP_ADDRESS \
        display="IP Address" \
        validator=validate_ip
    
    field_declare NETWORK_MASK \
        display="Network Mask" \
        validator=validate_netmask
    
    field_declare NETWORK_GATEWAY \
        display="Gateway" \
        validator=validate_ip
    
    field_declare NETWORK_DNS_PRIMARY \
        display="Primary DNS" \
        default="1.1.1.1" \
        validator=validate_ip
    
    field_declare NETWORK_DNS_SECONDARY \
        display="Secondary DNS" \
        default="1.0.0.1" \
        validator=validate_ip
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
