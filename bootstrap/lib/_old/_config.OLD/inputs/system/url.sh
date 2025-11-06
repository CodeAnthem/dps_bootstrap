#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - URL
# Feature:       URL format validation (http, https, git, ssh)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# URL INPUT
# ----------------------------------------------------------------------------------

validate_url() {
    local url="$1"
    [[ "$url" =~ ^(https?|git|ssh):// ]]
}

error_msg_url() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Invalid URL (must start with http://, https://, git://, or ssh://)"
}
