#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-22
# Description:   Script Library File
# Feature:       Custom configuration module (admin user, SSH, timezone)
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
custom_init_callback() {
    # MODULE_CONTEXT is already set to "custom"
    
    field_declare ADMIN_USER \
        display="Admin Username" \
        default="admin" \
        validator=validate_username
    
    field_declare SSH_PORT \
        display="SSH Port" \
        default="22" \
        type=number \
        validator=validate_port
    
    field_declare TIMEZONE \
        display="Timezone" \
        default="UTC" \
        validator=validate_timezone \
        error="Invalid timezone (examples: UTC, Europe/Zurich, America/New_York, Asia/Tokyo)"
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
custom_get_active_fields() {
    # All custom fields are always active
    echo "ADMIN_USER"
    echo "SSH_PORT"
    echo "TIMEZONE"
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
custom_validate_extra() {
    # No cross-field validation needed
    return 0
}
