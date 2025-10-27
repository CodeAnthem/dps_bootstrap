#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-22
# Description:   Script Library File
# Feature:       system configuration module (admin user, SSH, timezone)
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
    
    nds_field_declare SSH_PORT \
        display="SSH Port" \
        input=port \
        default="22" \
        required=true \
        min=1 \
        max=65535
    
    nds_field_declare TIMEZONE \
        display="Timezone" \
        input=timezone \
        default="UTC" \
        required=true
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
system_get_active_fields() {
    # All system fields are always active
    echo "ADMIN_USER"
    echo "SSH_PORT"
    echo "TIMEZONE"
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
system_validate_extra() {
    # No cross-field validation needed
    return 0
}
