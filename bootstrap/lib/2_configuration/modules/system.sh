#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-27
# Description:   System user configuration
# Feature:       Admin user and system-level settings
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
system_init_callback() {
    # MODULE_CONTEXT is already set to "system"
    
    nds_field_declare ADMIN_USER \
        display="Admin Username" \
        input=username \
        default="admin" \
        required=true
}

# Note: No need for system_get_active_fields() - auto-generates all fields
# Note: No need for system_validate_extra() - no cross-field validation
