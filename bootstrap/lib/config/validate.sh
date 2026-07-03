#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration validators
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-03
# Description:   Shared field validators (used by ask helpers and self-tests)
# ==================================================================================================

# Legacy test harness sets options here for validate_choice / validate_port.
declare -gA VALIDATOR_OPTIONS=()

validate_ip() {
    local ip="$1"
    local IFS=.
    local -a octets
    read -r -a octets <<< "$ip"
    (( ${#octets[@]} == 4 )) || return 1
    local i octet
    for i in "${!octets[@]}"; do
        octet="${octets[i]}"
        [[ $octet =~ ^[0-9]+$ ]] || return 1
        [[ $octet == "0" || $octet != 0[0-9]* ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
        (( i == 0 )) && (( octet < 1 )) && return 1
        (( i == 3 )) && (( octet == 0 || octet == 255 )) && return 1
    done
    return 0
}

validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
    [[ ${#hostname} -ge 2 ]] || return 1
    [[ "$hostname" =~ $hostname_regex ]]
}

error_msg_hostname() {
    echo "Invalid hostname (2-63 chars, lowercase alphanumeric, hyphens allowed in middle)"
}

validate_username() {
    local username="$1"
    [[ ${#username} -ge 2 ]] || return 1
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{1,31}$ ]]
}

validate_port() {
    local value="$1" min max
    min="${VALIDATOR_OPTIONS[min]:-1}"
    max="${VALIDATOR_OPTIONS[max]:-65535}"
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    (( value >= min && value <= max )) || return 2
    return 0
}

validate_int() {
    local value="$1" min max
    min="${2:-${VALIDATOR_OPTIONS[min]:-}}"
    max="${3:-${VALIDATOR_OPTIONS[max]:-}}"
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
    [[ -n "$min" && "$value" -lt "$min" ]] && return 2
    [[ -n "$max" && "$value" -gt "$max" ]] && return 2
    return 0
}

validate_choice() {
    local value="$1" options="${2:-${VALIDATOR_OPTIONS[options]:-}}"
    [[ -n "$options" ]] || return 3
    local choice
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        [[ "$value" == "$choice" ]] && return 0
    done
    return 1
}

validate_toggle() {
    [[ "${1,,}" =~ ^(true|false|enabled|disabled|yes|no|y|n|1|0)$ ]]
}

error_msg_toggle() {
    echo "Enter yes, no, true, false, enabled, or disabled"
}

validate_path() {
    local path="$1"
    [[ "$path" =~ ^(/|~|\.) ]]
}

validate_url() {
    [[ "$1" =~ ^(https?|git|ssh):// ]] && return 0
    # SCP-style git remotes, e.g. git@github.com:owner/repo.git
    [[ "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:.+ ]]
}

validate_disk() {
    [[ -n "$1" && -b "$1" ]]
}

validate_locale() {
    [[ "$1" =~ ^[a-z]{2}_[A-Z]{2}\.(UTF-8|utf8)$ ]]
}

validate_keyboard() {
    local value="$1"
    [[ "$value" =~ ^[a-z0-9-]+$ ]] || return 1
    local len=${#value}
    (( len >= 2 && len <= 15 )) || return 1
    return 0
}

validate_timezone() {
    local tz="$1"
    [[ -n "$tz" ]] || return 1
    if command -v timedatectl &>/dev/null; then
        local timezones
        if timezones=$(timedatectl list-timezones 2>/dev/null) && [[ -n "$timezones" ]]; then
            grep -qxi "$tz" <<< "$timezones" && return 0
            return 1
        fi
    fi
    case "$tz" in
        UTC|GMT) return 0 ;;
    esac
    [[ "$tz" =~ ^[A-Za-z0-9_+-]+/[A-Za-z0-9_+-]+$ ]] && return 0
    return 1
}

validate_country() {
    local value="$1"
    [[ "$value" =~ ^[A-Za-z]{2}$ ]] || return 1
    nds_country_defaults "${value,,}" &>/dev/null || return 2
    return 0
}

validate_mask() {
    local mask="$1"
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        [[ "$mask" -ge 1 && "$mask" -le 32 ]] && return 0
        return 1
    fi
    local IFS=. val=0 octet
    local -a octets
    read -r -a octets <<< "$mask"
    (( ${#octets[@]} == 4 )) || return 1
    for octet in "${octets[@]}"; do
        [[ $octet =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
        (( val = (val << 8) | octet ))
    done
    (( val != 0 && val != 0xFFFFFFFF )) || return 1
    (( (val | (val - 1)) == 0xFFFFFFFF )) || return 1
    return 0
}

nds_validate_cidr_to_netmask() {
    local cidr="$1" octets=() i bits_in_octet octet_value bit
    for ((i=0; i<4; i++)); do
        if (( cidr >= 8 )); then bits_in_octet=8
        elif (( cidr > 0 )); then bits_in_octet=$cidr
        else bits_in_octet=0; fi
        octet_value=0
        for ((bit=0; bit<bits_in_octet; bit++)); do
            (( octet_value += 1 << (7 - bit) ))
        done
        octets+=("$octet_value")
        (( cidr -= 8 ))
        (( cidr < 0 )) && cidr=0
    done
    echo "${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
}

nds_validate_mask_to_prefix() {
    local mask="$1" val=0 octet count=0
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        echo "$mask"
        return 0
    fi
    local IFS=.
    local -a octets
    read -r -a octets <<< "$mask"
    for octet in "${octets[@]}"; do
        (( val = (val << 8) | octet ))
    done
    while (( val )); do
        (( count += val & 1 ))
        (( val >>= 1 ))
    done
    echo "$count"
}

nds_validate_ip_to_int() {
    local ip="$1" a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

nds_validate_same_subnet() {
    local ip="$1" mask="$2" gateway="$3"
    local ip_int gateway_int mask_int ip_network gateway_network
    ip_int=$(nds_validate_ip_to_int "$ip")
    gateway_int=$(nds_validate_ip_to_int "$gateway")
    mask_int=$(nds_validate_ip_to_int "$mask")
    ip_network=$((ip_int & mask_int))
    gateway_network=$((gateway_int & mask_int))
    [[ "$ip_network" -eq "$gateway_network" ]]
}
