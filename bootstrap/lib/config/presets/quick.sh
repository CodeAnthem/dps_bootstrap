#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Quick Setup Module - Fast configuration with smart defaults
# Feature:       Country-based automatic configuration for rapid deployment
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
quick_init() {
    # Country selection for auto-defaults
    nds_configurator_var_declare COUNTRY \
        display="Country (Quick Setup)" \
        input=country \
        default="" \
        help="Select your country to automatically configure timezone, locale, and keyboard. This is the fastest way to get started! Leave empty to configure manually in other modules."
}

# =============================================================================
# MODULE METADATA
# =============================================================================
quick_module_info() {
    cat <<EOF
{
  "name": "quick",
  "display": "Quick Setup",
  "description": "Fast deployment with country-based smart defaults",
  "priority": 1
}
EOF
}
