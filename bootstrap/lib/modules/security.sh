#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-28
# Description:   Security Module - Configuration & NixOS Generation
# Feature:       Secure boot, firewall, hardening, and security configuration
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
security_init_callback() {
    nds_field_declare SECURE_BOOT \
        display="Enable Secure Boot" \
        input=toggle \
        default=false
    
    nds_field_declare SECURE_BOOT_METHOD \
        display="Secure Boot Method" \
        input=choice \
        default="lanzaboote" \
        options="lanzaboote|sbctl"
    
    nds_field_declare FIREWALL_ENABLE \
        display="Enable Firewall" \
        input=toggle \
        required=true \
        default=true
    
    nds_field_declare HARDENING_ENABLE \
        display="Apply Security Hardening" \
        input=toggle \
        default=true
    
    nds_field_declare FAIL2BAN_ENABLE \
        display="Enable Fail2Ban" \
        input=toggle \
        default=false
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
security_get_active_fields() {
    local secure_boot
    secure_boot=$(nds_config_get "security" "SECURE_BOOT")
    
    echo "SECURE_BOOT"
    
    if [[ "$secure_boot" == "true" ]]; then
        echo "SECURE_BOOT_METHOD"
    fi
    
    echo "FIREWALL_ENABLE"
    echo "HARDENING_ENABLE"
    echo "FAIL2BAN_ENABLE"
}

# =============================================================================
# CONFIGURATION - Cross-Field Validation
# =============================================================================
security_validate_extra() {
    # No cross-field validation needed
    return 0
}

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

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
    
    local block
    block=$(_nixcfg_security_generate "$secure_boot" "$secure_boot_method" "$firewall_enable" "$ssh_port" "$hardening" "$fail2ban")
    nds_nixcfg_register "security" "$block" 70
}

# Manual mode: explicit parameters
nds_nixcfg_security() {
    local secure_boot="${1:-false}"
    local secure_boot_method="${2:-lanzaboote}"
    local firewall_enable="${3:-true}"
    local ssh_port="${4:-22}"
    local hardening="${5:-true}"
    local fail2ban="${6:-false}"
    
    local block
    block=$(_nixcfg_security_generate "$secure_boot" "$secure_boot_method" "$firewall_enable" "$ssh_port" "$hardening" "$fail2ban")
    nds_nixcfg_register "security" "$block" 70
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

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
        output+="# Secure Boot via $secure_boot_method\n"
        if [[ "$secure_boot_method" == "lanzaboote" ]]; then
            output+="# See: https://github.com/nix-community/lanzaboote\n"
        else
            output+="# See: https://github.com/Foxboron/sbctl\n"
        fi
        output+="# Configure after installation\n\n"
    fi
    
    # Firewall configuration
    if [[ "$firewall_enable" == "true" ]]; then
        output+="networking.firewall = {\n"
        output+="  enable = true;\n"
        
        # Auto-add SSH port if provided
        if [[ -n "$ssh_port" ]]; then
            output+="  allowedTCPPorts = [ $ssh_port ];\n"
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
