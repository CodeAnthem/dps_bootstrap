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
network_init_callback() {    
    nds_field_declare NETWORK_METHOD \
        display="Network Method" \
        input=choice \
        default="dhcp" \
        required=true \
        options="dhcp|static"
    
    nds_field_declare NETWORK_IP \
        display="IP Address" \
        required=true \
        input=ip
    
    nds_field_declare NETWORK_MASK \
        display="Network Mask" \
        required=true \
        input=mask \
        default="255.255.255.0"
    
    nds_field_declare NETWORK_GATEWAY \
        display="Gateway" \
        required=true \
        input=ip
    
    nds_field_declare NETWORK_DNS_PRIMARY \
        display="Primary DNS" \
        input=ip \
        required=true \
        default="1.1.1.1"
    
    nds_field_declare NETWORK_DNS_SECONDARY \
        display="Secondary DNS" \
        input=ip \
        required=true \
        default="1.0.0.1"
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
network_get_active_fields() {
    local method
    method=$(nds_config_get "network" "NETWORK_METHOD")
    
    # Base fields always active
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
    method=$(nds_config_get "network" "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        local ip
        local mask
        local gateway
        
        ip=$(nds_config_get "network" "NETWORK_IP")
        mask=$(nds_config_get "network" "NETWORK_MASK")
        gateway=$(nds_config_get "network" "NETWORK_GATEWAY")
        
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

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_network_auto() {
    local method hostname
    method=$(nds_config_get "network" "NETWORK_METHOD")
    hostname=$(nds_config_get "system" "HOSTNAME")
    
    local block
    if [[ "$method" == "static" ]]; then
        block=$(_nixcfg_network_static \
            "$hostname" \
            "$(nds_config_get "network" "NETWORK_IP")" \
            "$(nds_config_get "network" "NETWORK_GATEWAY")" \
            "$(nds_config_get "network" "NETWORK_MASK")" \
            "$(nds_config_get "network" "NETWORK_DNS_PRIMARY")" \
            "$(nds_config_get "network" "NETWORK_DNS_SECONDARY")")
    else
        block=$(_nixcfg_network_dhcp \
            "$hostname" \
            "$(nds_config_get "network" "NETWORK_DNS_PRIMARY")" \
            "$(nds_config_get "network" "NETWORK_DNS_SECONDARY")")
    fi
    
    nds_nixcfg_register "network" "$block" 20
}

# Manual mode: explicit parameters
nds_nixcfg_network() {
    local method="$1"
    local hostname="$2"
    local ip="${3:-}"
    local gateway="${4:-}"
    local mask="${5:-24}"
    local dns_primary="${6:-1.1.1.1}"
    local dns_secondary="${7:-1.0.0.1}"
    
    local block
    if [[ "$method" == "static" ]]; then
        block=$(_nixcfg_network_static "$hostname" "$ip" "$gateway" "$mask" "$dns_primary" "$dns_secondary")
    else
        block=$(_nixcfg_network_dhcp "$hostname" "$dns_primary" "$dns_secondary")
    fi
    
    nds_nixcfg_register "network" "$block" 20
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_network_static() {
    local hostname="$1"
    local ip="$2"
    local gateway="$3"
    local mask="$4"
    local dns_primary="$5"
    local dns_secondary="$6"
    
    cat <<EOF
networking = {
  hostName = "$hostname";
  interfaces.eth0.ipv4.addresses = [{
    address = "$ip";
    prefixLength = $mask;
  }];
  defaultGateway = "$gateway";
  nameservers = [ "$dns_primary" "$dns_secondary" ];
};
EOF
}

_nixcfg_network_dhcp() {
    local hostname="$1"
    local dns_primary="$2"
    local dns_secondary="$3"
    
    cat <<EOF
networking = {
  hostName = "$hostname";
  networkmanager.enable = true;
  nameservers = [ "$dns_primary" "$dns_secondary" ];
};
EOF
}
