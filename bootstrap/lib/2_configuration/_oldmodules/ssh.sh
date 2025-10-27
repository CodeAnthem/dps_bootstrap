#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   Configuration Module - SSH Settings
# Feature:       SSH server, keys, and authentication configuration
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
ssh_init_callback() {
    nds_field_declare SSH_ENABLE \
        display="Enable SSH Server" \
        input=toggle \
        required=true \
        default=true
    
    nds_field_declare SSH_PORT \
        display="SSH Port" \
        input=port \
        default="22"
    
    nds_field_declare SSH_PASSWORD_AUTH \
        display="Allow Password Authentication" \
        input=toggle \
        default=false
    
    nds_field_declare SSH_ROOT_LOGIN \
        display="Permit Root Login" \
        input=choice \
        default="no" \
        options="yes|no|prohibit-password"
    
    nds_field_declare SSH_KEY_METHOD \
        display="SSH Key Method" \
        input=choice \
        default="auto" \
        options="auto|manual|none"
    
    nds_field_declare SSH_KEY_TYPE \
        display="SSH Key Type" \
        input=choice \
        default="ed25519" \
        options="ed25519|rsa|ecdsa"
    
    nds_field_declare SSH_KEY_PASSPHRASE \
        display="Use Key Passphrase" \
        input=toggle \
        default=false
    
    nds_field_declare SSH_KEY_PATH \
        display="SSH Key Path" \
        input=path \
        default="/root/.ssh/id_ed25519"
    
    nds_field_declare SSH_AUTHORIZED_KEYS \
        display="Authorized SSH Keys" \
        input=text \
        default=""
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
ssh_get_active_fields() {
    local ssh_enable key_method
    ssh_enable=$(nds_config_get "ssh" "SSH_ENABLE")
    key_method=$(nds_config_get "ssh" "SSH_KEY_METHOD")
    
    # Always show enable
    echo "SSH_ENABLE"
    
    # If SSH disabled, stop here
    [[ "$ssh_enable" != "true" ]] && return
    
    # SSH settings
    echo "SSH_PORT"
    echo "SSH_PASSWORD_AUTH"
    echo "SSH_ROOT_LOGIN"
    echo "SSH_KEY_METHOD"
    
    # Key generation fields
    if [[ "$key_method" == "auto" ]]; then
        echo "SSH_KEY_TYPE"
        echo "SSH_KEY_PASSPHRASE"
    elif [[ "$key_method" == "manual" ]]; then
        echo "SSH_KEY_PATH"
    fi
    
    echo "SSH_AUTHORIZED_KEYS"
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
ssh_validate_extra() {
    local ssh_enable password_auth key_method
    ssh_enable=$(nds_config_get "ssh" "SSH_ENABLE")
    password_auth=$(nds_config_get "ssh" "SSH_PASSWORD_AUTH")
    key_method=$(nds_config_get "ssh" "SSH_KEY_METHOD")
    
    [[ "$ssh_enable" != "true" ]] && return 0
    
    # Warn if password auth enabled with keys
    if [[ "$password_auth" == "true" && "$key_method" != "none" ]]; then
        warn "SSH key configured but password authentication is enabled"
        warn "Consider disabling password auth for better security"
    fi
    
    # Warn if no authentication method
    if [[ "$password_auth" == "false" && "$key_method" == "none" ]]; then
        validation_error "No SSH authentication method configured"
        return 1
    fi
    
    return 0
}
