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

# Auto-mode: reads from configuration modules + the generated admin password.
nds_nixcfg_access_auto() {
    local admin_user sudo_password ssh_enable ssh_port ssh_pw_auth admin_ssh_key
    admin_user=$(nds_config_get "access" "ACCESS_ADMIN_USER")
    sudo_password=$(nds_config_get "access" "ACCESS_SUDO_PASSWORD_REQUIRED")
    ssh_enable=$(nds_config_get "access" "ACCESS_SSH_ENABLE")
    ssh_port=$(nds_config_get "access" "ACCESS_SSH_PORT")
    ssh_pw_auth=$(nds_config_get "access" "ACCESS_SSH_PASSWORD_AUTH")
    admin_ssh_key=$(nds_config_get "access" "ACCESS_ADMIN_SSH_KEY")

    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_pw_auth" "$admin_ssh_key"
}

# Manual mode: explicit parameters
nds_nixcfg_access() {
    local admin_user="${1:-admin}"
    local sudo_password="${2:-true}"
    local ssh_enable="${3:-true}"
    local ssh_port="${4:-22}"
    local ssh_pw_auth="${5:-true}"
    local admin_ssh_key="${6:-}"

    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_pw_auth" "$admin_ssh_key"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# ==================================================================================================

# Description: Escape a string for safe embedding in a Nix double-quoted string.
# Nix recognizes only \\ \" and \${ as escapes; everything else stays literal.
_nixcfg_nix_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//\$\{/\\\$\{}"
    printf '%s' "$s"
}

_nixcfg_access_generate() {
    local admin_user="$1"
    local sudo_password="$2"
    local ssh_enable="$3"
    local ssh_port="$4"
    local ssh_pw_auth="$5"
    local admin_ssh_key="$6"

    # Read the resolved admin password from the runtime secrets dir (written
    # by _nixinstall_generate_access_secrets before config generation).
    local pw_file="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets/admin_password.txt"
    local admin_password=""
    [[ -f "$pw_file" ]] && admin_password=$(<"$pw_file")

    if [[ -z "$admin_password" ]]; then
        warn "Admin password file missing — falling back to 'changeme'. Run _nixinstall_generate_access_secrets first."
        admin_password="changeme"
    fi

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

    local block
    block=$(cat <<EOF
# Admin User
users.users.$admin_user = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" ];
  initialPassword = "${escaped_pw}";${key_block}
};

# Sudo Configuration
security.sudo.wheelNeedsPassword = $sudo_password;

# SSH Configuration
services.openssh = {
  enable = $ssh_enable;
  ports = [ $ssh_port ];
  settings = {
    PasswordAuthentication = $ssh_pw_nix;
    PermitRootLogin = "no";
    X11Forwarding = false;
  };
};
EOF
)

    nds_nixcfg_register "access" "$block" 30
}
