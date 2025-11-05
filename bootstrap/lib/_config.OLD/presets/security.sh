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
security_init() {
    # Set preset metadata
    nds_configurator_preset_set_display "security" "Security"
    nds_configurator_preset_set_priority "security" 40
    
    nds_configurator_var_declare SECURE_BOOT \
        display="Enable Secure Boot" \
        input=toggle \
        default=false
    
    nds_configurator_var_declare SECURE_BOOT_METHOD \
        display="Secure Boot Method" \
        input=choice \
        default="lanzaboote" \
        options="lanzaboote|sbctl"
    
    nds_configurator_var_declare FIREWALL_ENABLE \
        display="Enable Firewall" \
        input=toggle \
        required=true \
        default=true
    
    nds_configurator_var_declare HARDENING_ENABLE \
        display="Apply Security Hardening" \
        input=toggle \
        default=true
    
    nds_configurator_var_declare FAIL2BAN_ENABLE \
        display="Enable Fail2Ban" \
        input=toggle \
        default=false
}

# =============================================================================
# CONFIGURATION - Active Fields Logic
# =============================================================================
security_get_active() {
    local secure_boot
    secure_boot=$(nds_cfg_get "SECURE_BOOT")
    
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

