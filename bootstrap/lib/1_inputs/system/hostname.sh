#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-28
# Description:   Input Handler - Hostname
# Feature:       RFC 1123 compliant hostname validation
# ==================================================================================================

# =============================================================================
# HOSTNAME INPUT
# =============================================================================

validate_hostname() {
    local hostname="$1"
    
    # Minimum 2 chars, lowercase letters, digits, hyphens (not at start/end)
    local hostname_regex='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
    
    # Must be at least 2 characters
    [[ ${#hostname} -ge 2 ]] || return 1
    
    [[ "$hostname" =~ $hostname_regex ]]
}

error_msg_hostname() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Invalid hostname (2-63 chars, lowercase alphanumeric, hyphens allowed in middle)"
}
