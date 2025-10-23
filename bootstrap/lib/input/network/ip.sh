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

        # Must be all digits
        [[ $octet =~ ^[0-9]+$ ]] || return 1

        # Prevent leading zeros (except for "0")
        [[ $octet == 0 || $octet != 0[0-9]* ]] || return 1

        # Check numeric range
        (( octet >= 0 && octet <= 255 )) || return 1

        # Apply special rules
        (( i == 0 && octet < 1 )) && return 1 # first octet not 0
        (( i == 3 && octet == 255 || octet == 0 )) && return 1 # last octet not 255 or 0
    done

    return 0
}

error_msg_ip() {
    echo "Invalid IP address format (example: 192.168.1.1)"
}
