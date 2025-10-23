#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Input Unit - Timezone
# Feature:       Specialized validation for timezone strings
# ==================================================================================================

# =============================================================================
# TIMEZONE UNIT - Validation with format checking
# =============================================================================

# Validate timezone string
validate_timezone() {
    local tz="$1"
    
    # Empty not allowed
    [[ -z "$tz" ]] && return 1
    
    # Check if timezone file exists (if zoneinfo is available)
    if [[ -d "/usr/share/zoneinfo" ]]; then
        [[ -f "/usr/share/zoneinfo/$tz" ]] && return 0
    fi
    
    # Valid format: Region/City or just abbreviations
    # Accept: UTC, GMT, Region/City, Region/SubRegion/City
    if [[ "$tz" =~ ^[A-Z][A-Za-z_]+(/[A-Za-z_]+)+$ ]] || [[ "$tz" =~ ^(UTC|GMT|EST|PST|MST|CST|CET|EET|WET)$ ]]; then
        return 0
    fi
    
    return 1
}

# Timezone uses generic text prompt - no custom prompt needed
# Fields using this unit will use prompt_validated() from types/text.sh
