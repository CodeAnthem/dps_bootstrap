#!/usr/bin/env bash
# ==================================================================================================
# File:          custom.sh
# Description:   Custom configuration module
# Author:        DPS Project
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
