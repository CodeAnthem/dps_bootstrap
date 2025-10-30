#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-27
# Description:   Network Module - Configuration & NixOS Generation
# Feature:       Network method (DHCP/static), IP, DNS, gateway configuration and NixOS generation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
network_init() {
    nds_configurator_var_declare HOSTNAME \
        display="Hostname" \
        input=hostname \
        required=true
    
    nds_configurator_var_declare NETWORK_METHOD \
        display="Network Method" \
        input=choice \
        default="dhcp" \
        required=true \
        options="dhcp|static"
    
    nds_configurator_var_declare NETWORK_IP \
        display="IP Address" \
        required=true \
        input=ip
    
    nds_configurator_var_declare NETWORK_MASK \
        display="Network Mask" \
        required=true \
        input=mask \
        default="255.255.255.0"
    
    nds_configurator_var_declare NETWORK_GATEWAY \
        display="Gateway" \
        required=true \
        input=ip
    
    nds_configurator_var_declare NETWORK_DNS_PRIMARY \
        display="Primary DNS" \
        input=ip \
        required=true \
        default="1.1.1.1"
    
    nds_configurator_var_declare NETWORK_DNS_SECONDARY \
        display="Secondary DNS" \
        input=ip \
        required=true \
        default="1.0.0.1"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
network_get_active() {
    local method
    method=$(nds_configurator_config_get "NETWORK_METHOD")
    
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
# CONFIGURATION - Cross-Field Validation
# =============================================================================
network_validate_extra() {
    local method
    method=$(nds_configurator_config_get "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        local ip
        local mask
        local gateway
        
        ip=$(nds_configurator_config_get "NETWORK_IP")
        mask=$(nds_configurator_config_get "NETWORK_MASK")
        gateway=$(nds_configurator_config_get "NETWORK_GATEWAY")
        
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

# =============================================================================
# CONFIGURATION - Helper Functions
# =============================================================================

# Convert IP address to integer
ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

# Validate subnet relationship
validate_subnet() {
    local ip="$1"
    local mask="$2"
    local gateway="$3"
    
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
