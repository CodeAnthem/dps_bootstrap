#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-27
# Description:   Packages Module - Configuration & NixOS Generation
# Feature:       System packages and Nix configuration, NixOS generation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
packages_init_callback() {
    nds_field_declare ESSENTIAL_PACKAGES \
        display="Essential Packages (space-separated)" \
        input=string \
        default="vim git curl wget htop tmux"
    
    nds_field_declare ADDITIONAL_PACKAGES \
        display="Additional Packages (space-separated)" \
        input=string \
        default=""
    
    nds_field_declare ENABLE_FLAKES \
        display="Enable Nix Flakes" \
        input=toggle \
        default=true
}

# Note: No need for packages_get_active_fields() - auto-generates all fields

# =============================================================================
# CONFIGURATION - Cross-Field Validation
# =============================================================================
packages_validate_extra() {
    # No cross-field validation needed
    return 0
}

