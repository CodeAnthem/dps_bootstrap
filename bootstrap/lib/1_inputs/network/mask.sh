#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-24
# Description:   Input Handler - Network Mask
# Feature:       Network mask with CIDR to dotted decimal conversion
# ==================================================================================================

# =============================================================================
# MASK INPUT - Custom prompt with CIDR conversion
# =============================================================================

# Convert CIDR to dotted decimal netmask
cidr_to_netmask() {
    local cidr="$1"
    local octets=()

    for ((i=0; i<4; i++)); do
        local bits_in_octet
        if (( cidr >= 8 )); then
            bits_in_octet=8
        elif (( cidr > 0 )); then
            bits_in_octet=$cidr
        else
            bits_in_octet=0
        fi

        local octet_value=0
        for ((bit=0; bit<bits_in_octet; bit++)); do
            (( octet_value += 1 << (7 - bit) ))
        done

        octets+=("$octet_value")
        (( cidr -= 8 ))
        (( cidr < 0 )) && cidr=0
    done

    echo "${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
}

prompt_mask() {
    local display="$1"
    local current="$2"
    
    while true; do
        printf "  %-20s [%s] (CIDR: 24 or dotted: 255.255.255.0): " "$display" "$current" >&2
        read -r value < /dev/tty
        
        # Empty - keep current
        if [[ -z "$value" ]]; then
            echo "$current"
            return 0
        fi
        
        # Check if it's CIDR notation
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if [[ "$value" -ge 0 && "$value" -le 32 ]]; then
                # Convert CIDR to dotted decimal
                local dotted
                dotted=$(cidr_to_netmask "$value")
                echo "$dotted"
                return 0
            else
                console "    Error: CIDR must be between 1 and 32"
                continue
            fi
        fi
        
        # Check if it's dotted decimal format
        if validate_mask "$value"; then
            echo "$value"
            return 0
        else
            console "    Error: Invalid network mask format"
            console "    Use CIDR (e.g., 24) or dotted decimal (e.g., 255.255.255.0)"
        fi
    done
}

validate_mask() {
    local mask="$1"
    
    # Check if it's CIDR notation (0-32)
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        [[ "$mask" -ge 0 && "$mask" -le 32 ]]
        return $?
    fi
    
    # Check if it's dotted decimal (validate as IP)
    local IFS=.
    local -a octets
    local val=0

    read -r -a octets <<< "$mask"
    (( ${#octets[@]} == 4 )) || return 1

    for octet in "${octets[@]}"; do
        [[ $octet =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
        (( val = (val << 8) | octet ))
    done

    # must not be all 0s or all 1s
    (( val != 0 && val != 0xFFFFFFFF )) || return 1

    # contiguous 1s then 0s
    (( (val | (val - 1)) == 0xFFFFFFFF )) || return 1

    return 0
}

error_msg_mask() {
    echo "Invalid network mask (use CIDR like 24 or dotted decimal like 255.255.255.0)"
}
