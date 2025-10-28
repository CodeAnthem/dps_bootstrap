#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-28
# Description:   Input Handler - Timezone
# Feature:       Timezone validation with fuzzy search using timedatectl
# ==================================================================================================

# =============================================================================
# TIMEZONE INPUT - Custom prompt with fuzzy search
# =============================================================================

prompt_timezone() {
    local display="$1"
    local current="$2"
    
    while true; do
        printf "  %-20s [%s] (e.g., zurich, UTC, Europe/Zurich): " "$display" "$current" >&2
        read -r value < /dev/tty
        
        # Empty - keep current
        if [[ -z "$value" ]]; then
            return 0
        fi
        
        # Check if timedatectl is available
        if ! command -v timedatectl &>/dev/null; then
            # Fallback to basic validation if timedatectl not available
            if validate_timezone "$value"; then
                echo "$value"
                return 0
            else
                console "    Error: Invalid timezone format"
                continue
            fi
        fi
        
        # Try exact match first (case-insensitive)
        if timedatectl list-timezones | grep -qxi "$value"; then
            echo "$value"
            return 0
        fi
        
        # Try fuzzy search
        local match_count
        match_count=$(timedatectl list-timezones | grep -ci "$value" || echo "0")
        
        if [[ "$match_count" -eq 1 ]]; then
            # Single match - use it
            local matched_tz
            matched_tz=$(timedatectl list-timezones | grep -i "$value")
            console "    Auto-matched: $matched_tz"
            echo "$matched_tz"
            return 0
        elif [[ "$match_count" -gt 1 ]]; then
            # Multiple matches - show them
            console "    Multiple matches found:"
            timedatectl list-timezones | grep -i "$value" | head -10 | while read -r tz; do
                console "      - $tz"
            done
            if [[ "$match_count" -gt 10 ]]; then
                console "      ... and $((match_count - 10)) more"
            fi
            console "    Please be more specific"
        else
            console "    Error: No timezone matching '$value' found"
            console "    Try: UTC, Europe/Zurich, America/New_York, or search by city name"
        fi
    done
}

validate_timezone() {
    local tz="$1"
    
    [[ -z "$tz" ]] && return 1
    
    # NixOS always has timedatectl - use it exclusively
    if ! command -v timedatectl &>/dev/null; then
        return 2  # timedatectl not available
    fi
    
    # Get list and check - avoid pipe race condition
    local timezones
    timezones=$(timedatectl list-timezones 2>/dev/null) || return 3
    
    # Case-insensitive exact match
    if grep -qxi "$tz" <<< "$timezones"; then
        return 0
    fi
    
    return 1  # Not found
}

error_msg_timezone() {
    local value="$1"
    local code="$2"
    
    case "$code" in
        1) echo "Timezone '$value' not found in system timezone database" ;;
        2) echo "timedatectl command not available (required for timezone validation)" ;;
        3) echo "Failed to retrieve timezone list from timedatectl" ;;
        *) echo "Invalid timezone (examples: UTC, Europe/Zurich, America/New_York)" ;;
    esac
}
