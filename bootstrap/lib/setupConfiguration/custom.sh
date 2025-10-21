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
        required=false \
        default="admin" \
        validator=validate_username \
        error="Invalid username (lowercase, numbers, hyphens only)"
    
    field_declare SSH_PORT \
        display="SSH Port" \
        required=false \
        default="22" \
        type=number \
        min=1 \
        max=65535 \
        validator=validate_port \
        error="Invalid port (1-65535)"
    
    field_declare TIMEZONE \
        display="Timezone" \
        required=false \
        default="UTC" \
        validator=validate_timezone \
        error="Invalid timezone"
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

# =============================================================================
# MODULE REGISTRATION
# =============================================================================
config_register_module "custom" \
    "custom_init_callback" \
    "custom_get_active_fields"
