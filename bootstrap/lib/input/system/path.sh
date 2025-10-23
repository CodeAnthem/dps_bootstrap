#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Path
# Feature:       File/directory path validation
# ==================================================================================================

# =============================================================================
# PATH INPUT
# =============================================================================

validate_path() {
    local path="$1"
    # Accept absolute paths, ~ paths, or ./relative paths
    [[ "$path" =~ ^(/|~|\.) ]]
}

error_msg_path() {
    echo "Invalid path (must start with /, ~, or .)"
}
