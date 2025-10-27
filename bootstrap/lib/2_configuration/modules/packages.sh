#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   Configuration Module - Packages
# Feature:       System packages and Nix configuration
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
packages_init_callback() {
    field_declare ESSENTIAL_PACKAGES \
        display="Essential Packages (space-separated)" \
        input=string \
        default="vim git curl wget htop tmux"
    
    field_declare ADDITIONAL_PACKAGES \
        display="Additional Packages (space-separated)" \
        input=string \
        default=""
    
    field_declare ENABLE_FLAKES \
        display="Enable Nix Flakes" \
        input=toggle \
        default=true
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
packages_validate_extra() {
    # No cross-field validation needed
    return 0
}
