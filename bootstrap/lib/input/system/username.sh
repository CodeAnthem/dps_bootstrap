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
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

error_msg_username() {
    echo "Invalid username (must start with lowercase letter or underscore, max 32 chars)"
}
