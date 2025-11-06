#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   NixOS Config Generation - Access Module
# Feature:       Admin user, sudo, and SSH configuration for NixOS
# ==================================================================================================

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
