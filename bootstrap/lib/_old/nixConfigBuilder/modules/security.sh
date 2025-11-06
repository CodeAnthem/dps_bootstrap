#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   NixOS Config Generation - Security Module
# Feature:       Security hardening, firewall, Secure Boot, Fail2Ban
# ==================================================================================================

# ----------------------------------------------------------------------------------
# NIXOS CONFIG GENERATION - Public API
# ----------------------------------------------------------------------------------

# Auto-mode: reads from configuration modules
nds_nixcfg_security_auto() {
    local secure_boot secure_boot_method firewall_enable hardening fail2ban ssh_port
    secure_boot=$(nds_config_get "security" "SECURE_BOOT")
    secure_boot_method=$(nds_config_get "security" "SECURE_BOOT_METHOD")
    firewall_enable=$(nds_config_get "security" "FIREWALL_ENABLE")
    hardening=$(nds_config_get "security" "HARDENING_ENABLE")
    fail2ban=$(nds_config_get "security" "FAIL2BAN_ENABLE")
    
    # Get SSH port from access module to auto-add to firewall
    ssh_port=$(nds_config_get "access" "SSH_PORT")
    
    _nixcfg_security_generate "$secure_boot" "$secure_boot_method" "$firewall_enable" "$ssh_port" "$hardening" "$fail2ban"
}

# Manual mode: explicit parameters
nds_nixcfg_security() {
    local secure_boot="${1:-false}"
    local secure_boot_method="${2:-lanzaboote}"
    local firewall_enable="${3:-true}"
    local ssh_port="${4:-22}"
    local hardening="${5:-true}"
    local fail2ban="${6:-false}"
    
    _nixcfg_security_generate "$secure_boot" "$secure_boot_method" "$firewall_enable" "$ssh_port" "$hardening" "$fail2ban"
}

# ----------------------------------------------------------------------------------
# NIXOS CONFIG GENERATION - Implementation
# ----------------------------------------------------------------------------------

_nixcfg_security_generate() {
    local secure_boot="$1"
    local secure_boot_method="$2"
    local firewall_enable="$3"
    local ssh_port="$4"
    local hardening="$5"
    local fail2ban="$6"
    
    local output=""
    
    # Secure Boot
    if [[ "$secure_boot" == "true" ]]; then
        output="# Secure Boot via $secure_boot_method"
        if [[ "$secure_boot_method" == "lanzaboote" ]]; then
            output+="
# See: https://github.com/nix-community/lanzaboote"
        else
            output+="
# See: https://github.com/Foxboron/sbctl"
        fi
        output+="
# Configure after installation

"
    fi
    
    # Firewall configuration
    if [[ "$firewall_enable" == "true" ]]; then
        output+="networking.firewall = {
  enable = true;"
        
        # Auto-add SSH port if provided
        if [[ -n "$ssh_port" ]]; then
            output+="
  allowedTCPPorts = [ $ssh_port ];"
        fi
        
        output+="
};

"
    else
        output+="networking.firewall.enable = false;

"
    fi
    
    # Security hardening
    if [[ "$hardening" == "true" ]]; then
        output+="# Security hardening
security.hideProcessInformation = true;
security.lockKernelModules = true;
security.protectKernelImage = true;

"
    fi
    
    # Fail2Ban
    if [[ "$fail2ban" == "true" ]]; then
        output+="services.fail2ban = {
  enable = true;
  maxretry = 5;
};"
    fi
    
    nds_nixcfg_register "security" "$output" 70
}
