#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Username
# Feature:       Linux username validation
# ==================================================================================================

# =============================================================================
# USERNAME INPUT
# =============================================================================

validate_username() {
    local username="$1"
    
    # Minimum 2 characters for system administration
    [[ ${#username} -ge 2 ]] || return 1
    
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{1,31}$ ]]
}

error_msg_username() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Invalid username (2-32 chars, start with lowercase letter or underscore)"
}
