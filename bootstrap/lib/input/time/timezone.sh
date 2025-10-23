#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Timezone
# Feature:       Timezone validation (Region/City format or common abbreviations)
# ==================================================================================================

# =============================================================================
# TIMEZONE INPUT
# =============================================================================

prompt_hint_timezone() {
    echo "(e.g., UTC, Europe/Zurich, America/New_York)"
}

validate_timezone() {
    local tz="$1"
    
    [[ -z "$tz" ]] && return 1
    
    # Check if timezone file exists (if zoneinfo is available)
    if [[ -d "/usr/share/zoneinfo" ]]; then
        [[ -f "/usr/share/zoneinfo/$tz" ]] && return 0
    fi
    
    # Valid format: Region/City or just abbreviations
    if [[ "$tz" =~ ^[A-Z][A-Za-z_]+(/[A-Za-z_]+)+$ ]] || [[ "$tz" =~ ^(UTC|GMT|EST|PST|MST|CST|CET|EET|WET)$ ]]; then
        return 0
    fi
    
    return 1
}

error_msg_timezone() {
    echo "Invalid timezone format (examples: UTC, Europe/Zurich, America/New_York, Asia/Tokyo)"
}
