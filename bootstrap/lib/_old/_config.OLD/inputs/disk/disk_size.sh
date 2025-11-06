#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Disk Size
# Feature:       Disk size format validation (e.g., 8G, 500M, 1T)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# DISK_SIZE INPUT
# ----------------------------------------------------------------------------------

prompt_hint_disk_size() {
    echo "(e.g., 8G, 500M, 1T)"
}

validate_disk_size() {
    local size="$1"
    [[ "$size" =~ ^[0-9]+[KMGT]?$ ]]
}

error_msg_disk_size() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Invalid disk size format (examples: 8G, 500M, 1T, 50G)"
}
