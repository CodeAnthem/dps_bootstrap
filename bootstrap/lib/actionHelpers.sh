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

# Auto-skip if NDS_AUTO_CONFIRM is set to true
nds_autoSkip() {
    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        return 0
    fi
    return 1
}

# Ask user to proceed with yes/no prompt
# Usage: nds_askUserToProceed ["custom prompt"]
# Returns: 0 if user confirmed, 1 if declined
# Set NDS_AUTO_CONFIRM=true to auto-skip all prompts
nds_askUserToProceed() {
    local prompt="${1:-Do you want to proceed?}"
    
    # Auto-confirm if NDS_AUTO_CONFIRM is set to true
    if nds_autoSkip; then
        console "$prompt (y/n): y (auto-confirmed)"
        return 0
    fi
    
    read -rsp "$prompt (y/n): " -n 1 confirm < /dev/tty
    if [[ "${confirm,,}" != "y" ]]; then
        console "No!"
        return 1
    fi
    
    console "Yes!"
    return 0
}
