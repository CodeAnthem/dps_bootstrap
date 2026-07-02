#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration prompts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-01
# Description:   Interactive field prompts — all types in one place
# ==================================================================================================

nds_cfg_normalize_toggle() {
    case "${1,,}" in
        true|enabled|yes|y|1) echo "true" ;;
        false|disabled|no|n|0) echo "false" ;;
        *) echo "$1" ;;
    esac
}

nds_cfg_display_toggle() {
    nds_ui_format_bool "$1"
}

nds_cfg_display_choice() {
    local value="$1" labels="$2" pair option label
    [[ -z "$labels" ]] && { echo "$value"; return 0; }
    IFS='|' read -ra pairs <<< "$labels"
    for pair in "${pairs[@]}"; do
        option="${pair%%=*}"
        label="${pair#*=}"
        [[ "$value" == "$option" ]] && { echo "$label"; return 0; }
    done
    echo "$value"
}

nds_cfg_summary_row() {
    nds_ui_kv_row "$1" "$2"
}

nds_cfg_section_title() {
    nds_ui_h "$1:"
    nds_ui_b ""
}

_nds_cfg_prompt_value() {
    local var="$1" label="$2" hint="$3" required="${4:-false}"
    local current value

    current=$(nds_cfg_get "$var")
    while true; do
        if [[ -n "$hint" ]]; then
            printf "%s%-20s [%s] %s: " "$NDS_UI_INDENT_I" "$label" "$current" "$hint" >&2
        else
            printf "%s%-20s [%s]: " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        fi
        read -r value < /dev/tty
        if [[ -z "$value" ]]; then
            if [[ "$required" == true && -z "$current" ]]; then
                validation_error "$label is required"
                continue
            fi
            return 0
        fi
        printf '%s' "$value"
        return 0
    done
}

nds_cfg_ask_toggle() {
    local var="$1" label="$2" default="${3:-false}" hint="${4:-(yes/no, true/false)}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local current value normalized
    current=$(nds_cfg_get "$var")
    while true; do
        printf "%s%-20s [%s] %s: " "$NDS_UI_INDENT_I" "$label" "$(nds_cfg_display_toggle "$current")" "$hint" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if validate_toggle "$value"; then
            normalized=$(nds_cfg_normalize_toggle "$value")
            if [[ "$current" != "$normalized" ]]; then
                nds_cfg_set "$var" "$normalized"
                nds_ui_b "  -> Updated: $(nds_cfg_display_toggle "$current") -> $(nds_cfg_display_toggle "$normalized")"
            fi
            return 0
        fi
        nds_ui_b "  Error: Enter yes, no, true, false, enabled, or disabled"
    done
}

nds_cfg_ask_string() {
    local var="$1" label="$2" default="${3:-}" required="${4:-false}" hint="${5:-}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    value=$(_nds_cfg_prompt_value "$var" "$label" "$hint" "$required") || return 1
    [[ -z "$value" ]] && return 0
    if [[ "$current" != "$value" ]]; then
        nds_cfg_set "$var" "$value"
        nds_ui_b "  -> Set: $value"
    fi
}

nds_cfg_ask_secret() {
    local var="$1" label="$2" minlen="${3:-8}" required="${4:-false}"
    local current value
    current=$(nds_cfg_get "$var")
    while true; do
        if [[ -n "$current" ]]; then
            printf "%s%-20s [********]: " "$NDS_UI_INDENT_I" "$label" >&2
        else
            printf "%s%-20s: " "$NDS_UI_INDENT_I" "$label" >&2
        fi
        read -r -s value < /dev/tty
        echo >&2
        if [[ -z "$value" ]]; then
            [[ "$required" == true && -z "$current" ]] && { validation_error "$label is required"; continue; }
            return 0
        fi
        if [[ ${#value} -lt "$minlen" ]]; then
            nds_ui_b "  Error: Must be at least $minlen characters"
            continue
        fi
        nds_cfg_set "$var" "$value"
        nds_ui_b "  -> Set (hidden)"
        return 0
    done
}

nds_cfg_ask_int() {
    local var="$1" label="$2" default="$3" min="${4:-}" max="${5:-}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local hint="" value current
    if [[ -n "$min" && -n "$max" ]]; then hint="($min-$max)"
    elif [[ -n "$min" ]]; then hint="(min: $min)"
    elif [[ -n "$max" ]]; then hint="(max: $max)"
    fi
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "$hint" false) || continue
        [[ -z "$value" ]] && return 0
        if validate_int "$value" "$min" "$max"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Must be an integer${hint:+ $hint}"
    done
}

nds_cfg_ask_choice() {
    local var="$1" label="$2" options="$3" labels="${4:-}" default="${5:-}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local hint="(${options//|/, })" value current display
    current=$(nds_cfg_get "$var")
    while true; do
        display=$(nds_cfg_display_choice "$current" "$labels")
        value=$(_nds_cfg_prompt_value "$var" "$label" "$hint" false) || continue
        [[ -z "$value" ]] && return 0
        if validate_choice "$value" "$options"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Updated: $display -> $(nds_cfg_display_choice "$value" "$labels")"
            return 0
        fi
        nds_ui_b "  Error: Invalid choice. Options: ${options//|/, }"
    done
}

nds_cfg_ask_ip() {
    local var="$1" label="$2" default="${3:-}" required="${4:-false}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "(e.g. 192.168.1.1)" "$required") || continue
        [[ -z "$value" ]] && return 0
        if validate_ip "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid IP address"
    done
}

nds_cfg_ask_hostname() {
    local var="$1" label="$2" default="${3:-}" required="${4:-true}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "" "$required") || continue
        [[ -z "$value" ]] && return 0
        if validate_hostname "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: $(error_msg_hostname)"
    done
}

nds_cfg_ask_username() {
    local var="$1" label="$2" default="${3:-admin}" required="${4:-true}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "" "$required") || continue
        [[ -z "$value" ]] && return 0
        if validate_username "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid username"
    done
}

nds_cfg_ask_port() {
    nds_cfg_ask_int "$1" "$2" "$3" "${4:-1}" "${5:-65535}"
}

nds_cfg_ask_path() {
    local var="$1" label="$2" default="${3:-}" required="${4:-false}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "(absolute path)" "$required") || continue
        [[ -z "$value" ]] && return 0
        if validate_path "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Path must start with /, ~, or ."
    done
}

nds_cfg_ask_url() {
    local var="$1" label="$2" default="${3:-}" required="${4:-false}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "(https://, git://)" "$required") || continue
        [[ -z "$value" ]] && return 0
        if validate_url "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid URL"
    done
}

nds_cfg_list_disks() {
    local disks=() disk size
    while IFS= read -r disk; do
        if [[ -b "$disk" && ! "$disk" =~ [0-9]$ && ! "$disk" =~ loop ]]; then
            size=$(lsblk -b -d -o SIZE -n "$disk" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
            disks+=("$disk ($size)")
        fi
    done < <(find /dev -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' 2>/dev/null | sort)
    printf '%s\n' "${disks[@]}"
}

nds_cfg_ask_disk() {
    local var="$1" label="$2" default="${3:-}"
    local first_disk available_disks=() value i current
    first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)
    [[ -n "$default" ]] && first_disk="$default"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$first_disk"
    current=$(nds_cfg_get "$var")
    mapfile -t available_disks < <(nds_cfg_list_disks)
    nds_ui_b ""
    nds_ui_b "Available disks:"
    if [[ ${#available_disks[@]} -eq 0 ]]; then
        nds_ui_i "No disks found"
    else
        for i in "${!available_disks[@]}"; do
            nds_ui_i "$((i+1))) ${available_disks[i]}"
        done
    fi
    nds_ui_b ""
    while true; do
        printf "%s%-20s [%s]: " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= ${#available_disks[@]} )); then
            value="${available_disks[$((value-1))]%% *}"
        fi
        if validate_disk "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: '$value' is not a valid block device"
    done
}

nds_cfg_ask_mask() {
    local var="$1" label="$2" default="${3:-255.255.255.0}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local current value
    current=$(nds_cfg_get "$var")
    while true; do
        printf "%s%-20s [%s] (CIDR or dotted): " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if (( value >= 0 && value <= 32 )); then
                nds_cfg_set "$var" "$(nds_validate_cidr_to_netmask "$value")"
                nds_ui_b "  -> Set: $(nds_cfg_get "$var")"
                return 0
            fi
            nds_ui_b "  Error: CIDR must be 0-32"
            continue
        fi
        if validate_mask "$value"; then
            nds_cfg_set "$var" "$value"
            nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid network mask"
    done
}

nds_cfg_ask_timezone() {
    local var="$1" label="$2" default="${3:-UTC}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local current value matched_tz match_count
    current=$(nds_cfg_get "$var")
    while true; do
        printf "%s%-20s [%s] (e.g. Europe/Zurich): " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if command -v timedatectl &>/dev/null; then
            if timedatectl list-timezones | grep -qxi "$value"; then
                nds_cfg_set "$var" "$value"
                nds_ui_b "  -> Set: $value"
                return 0
            fi
            match_count=$(timedatectl list-timezones | grep -ci "$value" || echo "0")
            if [[ "$match_count" -eq 1 ]]; then
                matched_tz=$(timedatectl list-timezones | grep -i "$value")
                nds_cfg_set "$var" "$matched_tz"
                nds_ui_b "  -> Auto-matched: $matched_tz"
                return 0
            elif [[ "$match_count" -gt 1 ]]; then
                nds_ui_b "  Multiple matches — be more specific"
                continue
            fi
        elif validate_timezone "$value"; then
            nds_cfg_set "$var" "$value"
            nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid timezone"
    done
}

nds_cfg_ask_locale() {
    local var="$1" label="$2" default="${3:-en_US.UTF-8}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current normalized
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "(e.g. en_US.UTF-8)" true) || continue
        [[ -z "$value" ]] && return 0
        normalized="${value/.utf8/.UTF-8}"
        if validate_locale "$normalized"; then
            nds_cfg_set "$var" "$normalized"
            [[ "$current" != "$normalized" ]] && nds_ui_b "  -> Set: $normalized"
            return 0
        fi
        nds_ui_b "  Error: Invalid locale"
    done
}

nds_cfg_ask_keyboard() {
    local var="$1" label="$2" default="${3:-us}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_cfg_prompt_value "$var" "$label" "(us, de, ch)" true) || continue
        [[ -z "$value" ]] && return 0
        value="${value,,}"
        if validate_keyboard "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid keyboard layout"
    done
}

nds_cfg_ask_country() {
    local var="$1" label="$2"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" ""
    while true; do
        local value
        value=$(_nds_cfg_prompt_value "$var" "$label" "(US, DE, CH — empty = manual)" false) || continue
        [[ -z "$value" ]] && return 0
        value="${value^^}"
        if validate_country "$value"; then
            nds_cfg_set "$var" "$value"
            nds_country_apply "$value" && nds_ui_b "  -> Set: $value (applied region defaults)"
            return 0
        fi
        nds_ui_b "  Error: Unknown country code"
    done
}
