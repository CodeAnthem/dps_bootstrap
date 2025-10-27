#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-27
# Description:   System and user configuration
# Feature:       Hostname, admin user, shell, and system-level settings
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
system_init_callback() {
    # MODULE_CONTEXT is already set to "system"
    
    # System Identity
    nds_field_declare HOSTNAME \
        display="Hostname" \
        input=hostname \
        required=true
    
    # Admin User Settings
    nds_field_declare ADMIN_USER \
        display="Admin Username" \
        input=username \
        default="admin" \
        required=true
    
    nds_field_declare ADMIN_SHELL \
        display="Admin Shell" \
        input=choice \
        default="bash" \
        options="bash|zsh|fish|sh"
    
    nds_field_declare ADMIN_GROUPS \
        display="Additional Groups" \
        input=string \
        default="wheel,docker,networkmanager"
    
    # System Settings
    nds_field_declare AUTO_UPGRADE \
        display="Automatic System Updates" \
        input=toggle \
        default=true
    
    nds_field_declare DEFAULT_EDITOR \
        display="Default System Editor" \
        input=choice \
        default="vim" \
        options="vim|nano|emacs|helix|nvim"
}

# Note: No need for system_get_active_fields() - auto-generates all fields
# Note: No need for system_validate_extra() - no cross-field validation
