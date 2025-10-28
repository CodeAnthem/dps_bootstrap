#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   NixOS Config Builder Module - Security
# Feature:       Generate security and firewall configuration blocks
# ==================================================================================================

# =============================================================================
# PUBLIC API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_security_auto() {
    local firewall_enable tcp_ports udp_ports hardening fail2ban
    firewall_enable=$(nds_config_get "security" "FIREWALL_ENABLE")
    tcp_ports=$(nds_config_get "security" "FIREWALL_ALLOW_PORTS_TCP")
    udp_ports=$(nds_config_get "security" "FIREWALL_ALLOW_PORTS_UDP")
    hardening=$(nds_config_get "security" "HARDENING_ENABLE")
    fail2ban=$(nds_config_get "security" "FAIL2BAN_ENABLE")
    
    local block
    block=$(_nixcfg_security_generate "$firewall_enable" "$tcp_ports" "$udp_ports" "$hardening" "$fail2ban")
    nds_nixcfg_register "security" "$block" 70
}

# Manual mode: explicit parameters
nds_nixcfg_security() {
    local firewall_enable="${1:-true}"
    local tcp_ports="${2:-22}"
    local udp_ports="${3:-}"
    local hardening="${4:-true}"
    local fail2ban="${5:-false}"
    
    local block
    block=$(_nixcfg_security_generate "$firewall_enable" "$tcp_ports" "$udp_ports" "$hardening" "$fail2ban")
    nds_nixcfg_register "security" "$block" 70
}

# =============================================================================
# PRIVATE - Implementation Functions
# =============================================================================

_nixcfg_security_generate() {
    local firewall_enable="$1"
    local tcp_ports="$2"
    local udp_ports="$3"
    local hardening="$4"
    local fail2ban="$5"
    
    local output=""
    
    # Firewall configuration
    if [[ "$firewall_enable" == "true" ]]; then
        output+="networking.firewall = {\n"
        output+="  enable = true;\n"
        
        if [[ -n "$tcp_ports" ]]; then
            local tcp_array
            IFS=' ' read -ra tcp_array <<< "$tcp_ports"
            output+="  allowedTCPPorts = [ $(printf '%s ' "${tcp_array[@]}") ];\n"
        fi
        
        if [[ -n "$udp_ports" ]]; then
            local udp_array
            IFS=' ' read -ra udp_array <<< "$udp_ports"
            output+="  allowedUDPPorts = [ $(printf '%s ' "${udp_array[@]}") ];\n"
        fi
        
        output+="};\n\n"
    else
        output+="networking.firewall.enable = false;\n\n"
    fi
    
    # Security hardening
    if [[ "$hardening" == "true" ]]; then
        output+="# Security hardening\n"
        output+="security.hideProcessInformation = true;\n"
        output+="security.lockKernelModules = true;\n"
        output+="security.protectKernelImage = true;\n\n"
    fi
    
    # Fail2Ban
    if [[ "$fail2ban" == "true" ]]; then
        output+="services.fail2ban = {\n"
        output+="  enable = true;\n"
        output+="  maxretry = 5;\n"
        output+="};\n"
    fi
    
    echo -e "$output"
}
