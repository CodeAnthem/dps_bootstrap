#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   NixOS Config Builder Module - SSH
# Feature:       Generate SSH server configuration blocks
# ==================================================================================================

# =============================================================================
# PUBLIC API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_ssh_auto() {
    local ssh_enable ssh_port password_auth root_login
    ssh_enable=$(nds_config_get "ssh" "SSH_ENABLE")
    ssh_port=$(nds_config_get "ssh" "SSH_PORT")
    password_auth=$(nds_config_get "ssh" "SSH_PASSWORD_AUTH")
    root_login=$(nds_config_get "ssh" "SSH_ROOT_LOGIN")
    
    local block
    block=$(_nixcfg_ssh_generate "$ssh_enable" "$ssh_port" "$password_auth" "$root_login")
    nds_nixcfg_register "ssh" "$block" 50
}

# Manual mode: explicit parameters
nds_nixcfg_ssh() {
    local ssh_enable="${1:-true}"
    local ssh_port="${2:-22}"
    local password_auth="${3:-false}"
    local root_login="${4:-no}"
    
    local block
    block=$(_nixcfg_ssh_generate "$ssh_enable" "$ssh_port" "$password_auth" "$root_login")
    nds_nixcfg_register "ssh" "$block" 50
}

# =============================================================================
# PRIVATE - Implementation Functions
# =============================================================================

_nixcfg_ssh_generate() {
    local ssh_enable="$1"
    local ssh_port="$2"
    local password_auth="$3"
    local root_login="$4"
    
    if [[ "$ssh_enable" != "true" ]]; then
        echo "services.openssh.enable = false;"
        return
    fi
    
    cat <<EOF
services.openssh = {
  enable = true;
  ports = [ $ssh_port ];
  settings = {
    PasswordAuthentication = $password_auth;
    PermitRootLogin = "$root_login";
    X11Forwarding = false;
  };
};
EOF
}
