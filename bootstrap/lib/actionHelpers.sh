#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-10-29
# Description:   Generic action helper functions
# Feature:       Reusable utilities for action setup scripts
# ==================================================================================================

# =============================================================================
# USER INTERACTION HELPERS
# =============================================================================

# Ask user to proceed with yes/no prompt
# Usage: nds_askUserToProceed ["custom prompt"]
# Returns: 0 if user confirmed, 1 if declined
nds_askUserToProceed() {
    local prompt="${1:-Do you want to proceed?}"
    
    console ""
    console "$prompt (y/n): "
    read -r confirm
    
    if [[ "${confirm,,}" != "y" ]]; then
        return 1
    fi
    
    return 0
}
