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

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_access_auto() {
    local admin_user sudo_password ssh_enable ssh_port ssh_use_key
    admin_user=$(nds_config_get "access" "ADMIN_USER")
    sudo_password=$(nds_config_get "access" "SUDO_PASSWORD_REQUIRED")
    ssh_enable=$(nds_config_get "access" "SSH_ENABLE")
    ssh_port=$(nds_config_get "access" "SSH_PORT")
    ssh_use_key=$(nds_config_get "access" "SSH_USE_KEY")
    
    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_use_key"
}

# Manual mode: explicit parameters
nds_nixcfg_access() {
    local admin_user="${1:-admin}"
    local sudo_password="${2:-true}"
    local ssh_enable="${3:-true}"
    local ssh_port="${4:-22}"
    local ssh_use_key="${5:-true}"
    
    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_use_key"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_access_generate() {
    local admin_user="$1"
    local sudo_password="$2"
    local ssh_enable="$3"
    local ssh_port="$4"
    local ssh_use_key="$5"
    
    # Determine password authentication setting (inverse of ssh_use_key)
    local password_auth="false"
    [[ "$ssh_use_key" == "false" ]] && password_auth="true"
    
    local block
    block=$(cat <<EOF
# Admin User
users.users.$admin_user = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" ];
  initialPassword = "changeme";
};

# Sudo Configuration
security.sudo.wheelNeedsPassword = $sudo_password;

# SSH Configuration
services.openssh = {
  enable = $ssh_enable;
  ports = [ $ssh_port ];
  settings = {
    PasswordAuthentication = $password_auth;
    PermitRootLogin = "no";
    X11Forwarding = false;
  };
};
EOF
)
    
    nds_nixcfg_register "access" "$block" 30
}
