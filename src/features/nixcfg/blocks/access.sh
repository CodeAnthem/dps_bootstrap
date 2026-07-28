#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-02
# Description:   NixOS Config Generation - Access Module
# Feature:       Admin user, sudo, and SSH configuration for NixOS
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# ==================================================================================================

# Manual mode: explicit parameters (password required).
nds_nixcfg_access() {
    local admin_user="${1:-admin}"
    local sudo_password="${2:-true}"
    local ssh_enable="${3:-true}"
    local ssh_port="${4:-22}"
    local ssh_pw_auth="${5:-true}"
    local admin_ssh_key="${6:-}"
    local admin_password="${7:-changeme}"

    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_pw_auth" "$admin_ssh_key" "$admin_password"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# ==================================================================================================

_nixcfg_access_generate() {
    local admin_user="$1"
    local sudo_password="$2"
    local ssh_enable="$3"
    local ssh_port="$4"
    local ssh_pw_auth="$5"
    local admin_ssh_key="$6"
    local admin_password="$7"

    local escaped_pw ssh_pw_nix
    escaped_pw=$(_nixcfg_nix_escape "$admin_password")
    ssh_pw_nix="false"
    [[ "$ssh_pw_auth" == "true" ]] && ssh_pw_nix="true"

    local key_block=""
    if [[ -n "$admin_ssh_key" ]]; then
        local escaped_key
        escaped_key=$(_nixcfg_nix_escape "$admin_ssh_key")
        key_block=$'\n  openssh.authorizedKeys.keys = [ "'"${escaped_key}"'" ];'
    fi

    # Quoted heredoc + @@TOKEN@@ substitution: no bash expansion, no escaping.
    # User-controlled values (key block, password) filled last.
    local block
    block=$(nds_nixcfg_subst "$(cat <<'EOF'
# Admin User
users.users.@@ADMIN_USER@@ = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" ];
  initialPassword = "@@PASSWORD@@";@@KEY_BLOCK@@
};

# Sudo Configuration
security.sudo.wheelNeedsPassword = @@SUDO_PASSWORD@@;

# SSH Configuration
services.openssh = {
  enable = @@SSH_ENABLE@@;
  ports = [ @@SSH_PORT@@ ];
  settings = {
    PasswordAuthentication = @@SSH_PW_NIX@@;
    PermitRootLogin = "no";
    X11Forwarding = false;
  };
};
EOF
)" @@ADMIN_USER@@ "$admin_user" @@SUDO_PASSWORD@@ "$sudo_password" @@SSH_ENABLE@@ "$ssh_enable" @@SSH_PORT@@ "$ssh_port" @@SSH_PW_NIX@@ "$ssh_pw_nix" @@KEY_BLOCK@@ "$key_block" @@PASSWORD@@ "$escaped_pw")

    nds_nixcfg_register "access" "$block" 30
}
