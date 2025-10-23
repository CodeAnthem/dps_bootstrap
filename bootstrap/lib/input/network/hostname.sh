#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Hostname
# Feature:       RFC 1123 compliant hostname validation
# ==================================================================================================

# =============================================================================
# HOSTNAME INPUT
# =============================================================================

validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
    
    [[ "$hostname" =~ $hostname_regex ]]
}

error_msg_hostname() {
    echo "Invalid hostname (must start/end with alphanumeric, hyphens allowed in middle, max 63 chars)"
}
