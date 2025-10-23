#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Common validation functions used across multiple modules
# ==================================================================================================

# =============================================================================
# VALIDATE TIMEZONE
# =============================================================================
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
