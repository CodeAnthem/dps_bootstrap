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
    # MODULE_CONTEXT is already set to "network"
    
    field_declare HOSTNAME \
        display="Hostname" \
        required=true \
        default="" \
        validator=validate_hostname \
        error="Invalid hostname format"
    
    field_declare NETWORK_METHOD \
        display="Network Method" \
        required=true \
        default=dhcp \
        type=choice \
        options="dhcp|static" \
        validator=validate_choice
    
    field_declare IP_ADDRESS \
        display="IP Address" \
        required=false \
        default="" \
        validator=validate_ip \
        error="Invalid IP address"
    
    field_declare NETWORK_MASK \
        display="Network Mask" \
        required=false \
        default="" \
        validator=validate_netmask \
        error="Invalid netmask"
    
    field_declare NETWORK_GATEWAY \
        display="Gateway" \
        required=false \
        default="" \
        validator=validate_ip \
        error="Invalid gateway IP"
    
    field_declare NETWORK_DNS_PRIMARY \
        display="Primary DNS" \
        required=false \
        default="1.1.1.1" \
        validator=validate_ip \
        error="Invalid DNS IP"
    
    field_declare NETWORK_DNS_SECONDARY \
        display="Secondary DNS" \
        required=false \
        default="1.0.0.1" \
        validator=validate_ip \
        error="Invalid DNS IP"
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
        
        # All three must be present for static
        if [[ -n "$ip" && -n "$mask" && -n "$gateway" ]]; then
            # Validate gateway is in same subnet
            if ! validate_same_subnet "$ip" "$mask" "$gateway"; then
                validation_error "Gateway $gateway must be in the same subnet as $ip/$mask"
                return 1
            fi
        fi
    fi
    
    return 0
}

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
config_register_module "network" \
    "network_init_callback" \
    "network_get_active_fields"
