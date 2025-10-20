#!/usr/bin/env bash
# ==================================================================================================
# File:          validators.sh
# Description:   Common validation functions for configuration values
# Author:        DPS Project
# ==================================================================================================

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

# Validate disk path exists
# Usage: validate_disk_path "/dev/sda"
validate_disk_path() {
    local disk_path="$1"
    [[ -b "$disk_path" ]]
}

# Validate disk size format
# Usage: validate_disk_size "8G" [allow_remaining]
validate_disk_size() {
    local size="$1"
    local allow_remaining="${2:-false}"
    
    if [[ "$allow_remaining" == "true" ]]; then
        [[ "$size" =~ ^[0-9]+[GMT]$ || "$size" == "remaining" || "$size" == "*" ]]
    else
        [[ "$size" =~ ^[0-9]+[GMT]$ ]]
    fi
}

# Validate yes/no input
# Usage: validate_yes_no "y"
validate_yes_no() {
    local input="$1"
    local normalized="${input,,}"
    [[ "$normalized" =~ ^(y|yes|n|no)$ ]]
}

# Validate port number
# Usage: validate_port "22"
validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]
}

# Validate timezone
# Usage: validate_timezone "UTC" or validate_timezone "Europe/Berlin"
validate_timezone() {
    local tz="$1"
    
    # Check if timezone exists
    if [[ -f "/usr/share/zoneinfo/$tz" ]]; then
        return 0
    fi
    
    # Common timezone abbreviations
    case "$tz" in
        UTC|GMT|EST|PST|MST|CST) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate username
# Usage: validate_username "admin"
validate_username() {
    local username="$1"
    # Linux username rules: start with letter/underscore, contain letters/numbers/underscore/dash
    local username_regex='^[a-z_][a-z0-9_-]{0,31}$'
    [[ "$username" =~ $username_regex ]]
}

# Validate file path exists
# Usage: validate_file_path "/path/to/file"
validate_file_path() {
    local path="$1"
    [[ -f "$path" ]]
}

# Validate choice from options
# Usage: validate_choice "dhcp" "dhcp|static"
validate_choice() {
    local value="$1"
    local options="$2"
    
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        if [[ "$value" == "$choice" ]]; then
            return 0
        fi
    done
    return 1
}

# Convert size string to bytes
# Usage: convert_size_to_bytes "8G"
convert_size_to_bytes() {
    local size="$1"
    local num="${size%?}"
    local unit="${size: -1}"
    
    case "$unit" in
        G) echo $((num * 1024 * 1024 * 1024)) ;;
        M) echo $((num * 1024 * 1024)) ;;
        T) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "0" ;;
    esac
}
