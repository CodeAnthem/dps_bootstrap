#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Network Mask
# Feature:       Network mask validation (CIDR notation or dotted decimal)
# ==================================================================================================

prompt_hint_mask() {
    echo "(CIDR: 24 or dotted: 255.255.255.0)"
}

validate_mask() {
    local mask="$1"
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
