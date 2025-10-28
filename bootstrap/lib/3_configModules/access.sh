#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Access Module - Configuration & NixOS Generation
# Feature:       User access, SSH, and authentication configuration
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
access_init_callback() {
    # Admin User
    nds_field_declare ADMIN_USER \
        display="Admin Username" \
        input=username \
        default="admin" \
        required=true
    
    nds_field_declare SUDO_PASSWORD_REQUIRED \
        display="Require Password for Sudo" \
        input=toggle \
        default=true
    
    # SSH Configuration
    nds_field_declare SSH_ENABLE \
        display="Enable SSH Server" \
        input=toggle \
        required=true \
        default=true
    
    nds_field_declare SSH_PORT \
        display="SSH Port" \
        input=port \
        default="22"
    
    nds_field_declare SSH_USE_KEY \
        display="Use SSH Key Authentication" \
        input=toggle \
        default=true
    
    # SSH Key Configuration (only if SSH_USE_KEY is enabled)
    nds_field_declare SSH_KEY_TYPE \
        display="SSH Key Type" \
        input=choice \
        default="ed25519" \
        options="ed25519|rsa|ecdsa"
    
    nds_field_declare SSH_KEY_PASSPHRASE \
        display="Protect Key with Passphrase" \
        input=toggle \
        default=false
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
access_get_active_fields() {
    local ssh_enable ssh_use_key
    ssh_enable=$(nds_config_get "access" "SSH_ENABLE")
    ssh_use_key=$(nds_config_get "access" "SSH_USE_KEY")
    
    # Always show user and sudo settings
    echo "ADMIN_USER"
    echo "SUDO_PASSWORD_REQUIRED"
    echo "SSH_ENABLE"
    
    # If SSH disabled, stop here
    [[ "$ssh_enable" != "true" ]] && return
    
    # SSH settings
    echo "SSH_PORT"
    echo "SSH_USE_KEY"
    
    # Key configuration if enabled
    if [[ "$ssh_use_key" == "true" ]]; then
        echo "SSH_KEY_TYPE"
        echo "SSH_KEY_PASSPHRASE"
    fi
}

# =============================================================================
# CONFIGURATION - Cross-Field Validation
# =============================================================================
access_validate_extra() {
    local ssh_enable ssh_use_key
    ssh_enable=$(nds_config_get "access" "SSH_ENABLE")
    ssh_use_key=$(nds_config_get "access" "SSH_USE_KEY")
    
    [[ "$ssh_enable" != "true" ]] && return 0
    
    # Warn if SSH enabled without key authentication
    if [[ "$ssh_use_key" == "false" ]]; then
        warn "SSH password authentication is less secure than key-based authentication"
    fi
    
    return 0
}

