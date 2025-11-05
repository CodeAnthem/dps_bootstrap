#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Network Preset
# Feature:       Network method (DHCP/static), IP, DNS, gateway configuration
# ==================================================================================================

# Create preset
nds_cfg_preset_create "network" \
    --display "Network" \
    --priority 10

# Base settings (always visible)
nds_cfg_setting_create HOSTNAME \
    --type hostname \
    --display "Hostname" \
    --default ""

nds_cfg_setting_create NETWORK_METHOD \
    --type choice \
    --display "Network Method" \
    --default "dhcp" \
    --options "dhcp|static"

nds_cfg_setting_create NETWORK_DNS_PRIMARY \
    --type ip \
    --display "Primary DNS" \
    --default "1.1.1.1"

nds_cfg_setting_create NETWORK_DNS_SECONDARY \
    --type ip \
    --display "Secondary DNS" \
    --default "1.0.0.1"

# Static network settings (visible only if static method selected)
nds_cfg_setting_create NETWORK_IP \
    --type ip \
    --display "IP Address" \
    --default "" \
    --visible_all "NETWORK_METHOD==static"

nds_cfg_setting_create NETWORK_MASK \
    --type netmask \
    --display "Network Mask" \
    --default "255.255.255.0" \
    --visible_all "NETWORK_METHOD==static"

nds_cfg_setting_create NETWORK_GATEWAY \
    --type ip \
    --display "Gateway" \
    --default "" \
    --visible_all "NETWORK_METHOD==static"

# Preset validation function
_network_validate() {
    local method
    method=$(nds_cfg_get NETWORK_METHOD)
    
    if [[ "$method" == "static" ]]; then
        local ip
        local mask
        local gateway
        
        ip=$(nds_cfg_get NETWORK_IP)
        mask=$(nds_cfg_get NETWORK_MASK)
        gateway=$(nds_cfg_get NETWORK_GATEWAY)
        
        # Check if Gateway is same as IP
        if [[ -n "$ip" && -n "$gateway" && "$ip" == "$gateway" ]]; then
            error "Gateway cannot be the same as IP address"
            return 1
        fi

        # All three must be present for subnet validation
        if [[ -n "$ip" && -n "$mask" && -n "$gateway" ]]; then
            # Validate gateway is in same subnet
            if ! _network_validate_subnet "$ip" "$mask" "$gateway"; then
                error "Gateway $gateway must be in the same subnet as $ip/$mask"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Helper: Convert IP address to integer
_network_ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

# Helper: Validate subnet relationship
_network_validate_subnet() {
    local ip="$1"
    local mask="$2"
    local gateway="$3"
    
    local ip_int
    local gateway_int
    local mask_int
    
    ip_int=$(_network_ip_to_int "$ip")
    gateway_int=$(_network_ip_to_int "$gateway")
    mask_int=$(_network_ip_to_int "$mask")
    
    # Apply mask to both IPs and compare
    local ip_network=$((ip_int & mask_int))
    local gateway_network=$((gateway_int & mask_int))
    
    [[ "$ip_network" -eq "$gateway_network" ]]
}

# Clear context
CFG_CONTEXT_PRESET=""
