#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - IP Address
# Feature:       No Regex, No Leading Zeros, No Broadcast Address
# ==================================================================================================

validate_ip() {
    local ip="$1"
    local IFS=.
    local -a octets

    # Split into octets
    read -r -a octets <<< "$ip"

    # Must be exactly 4 octets
    (( ${#octets[@]} == 4 )) || return 1

    for i in "${!octets[@]}"; do
        local octet="${octets[i]}"

        # Must be non-empty and only digits
        [[ $octet =~ ^[0-9]+$ ]] || return 1

        # Prevent leading zeros (allow only "0" exactly)
        [[ $octet == "0" || $octet != 0[0-9]* ]] || return 1

        # Numeric range 0..255
        (( octet >= 0 && octet <= 255 )) || return 1

        # Special rules:
        # - first octet must be >= 1
        if (( i == 0 )) && (( octet < 1 )); then
            return 1
        fi

        # - last octet must not be 0 or 255
        if (( i == 3 )) && (( octet == 0 || octet == 255 )); then
            return 1
        fi
    done

    return 0
}


error_msg_ip() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Invalid IP address format (example: 192.168.1.1)"
}
