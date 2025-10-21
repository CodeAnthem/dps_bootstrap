#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Network-related validation functions
# ==================================================================================================

# =============================================================================
# IP AND NETWORK VALIDATION FUNCTIONS
# =============================================================================

# Validate IP address (IPv4)
# Usage: validate_ip "192.168.1.1"
validate_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "$ip" =~ $ip_regex ]]; then
        return 1
    fi
    
    # Check each octet is 0-255
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ "$octet" -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}

# Convert CIDR to dotted decimal netmask
# Usage: cidr_to_netmask "24" → "255.255.255.0"
cidr_to_netmask() {
    local cidr="$1"
    local mask=""
    local full=$((cidr / 8))
    local partial=$((cidr % 8))
    
    # Full octets (255)
    for ((i=0; i<full; i++)); do
        mask+="255"
        [[ $i -lt 3 ]] && mask+="."
    done
    
    # Partial octet
    if [[ $full -lt 4 ]]; then
        [[ $full -gt 0 ]] && mask+="."
        local partial_value=$((256 - (256 >> partial)))
        mask+="$partial_value"
        
        # Remaining zero octets
        for ((i=full+1; i<4; i++)); do
            mask+=".0"
        done
    fi
    
    echo "$mask"
}

# Validate network mask (CIDR notation or dotted decimal)
# Usage: validate_netmask "255.255.255.0" or validate_netmask "24"
validate_netmask() {
    local mask="$1"
    
    # Check if it's CIDR notation (0-32)
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        [[ "$mask" -ge 0 && "$mask" -le 32 ]]
        return $?
    fi
    
    # Check if it's dotted decimal
    validate_ip "$mask"
}

# Validate hostname
# Usage: validate_hostname "server-01"
validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
    
    [[ "$hostname" =~ $hostname_regex ]]
}

# Validate subnet relationship
# Usage: validate_subnet "192.168.1.10" "192.168.1.1" "255.255.255.0"
validate_subnet() {
    local ip="$1"
    local gateway="$2"
    local mask="$3"
    
    # Validate each component first
    validate_ip "$ip" || return 1
    validate_ip "$gateway" || return 1
    validate_ip "$mask" || return 1
    
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

# Convert IP address to integer
# Usage: ip_to_int "192.168.1.1"
ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

# Validate port number
# Usage: validate_port "22"
validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]
}
