#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   Configuration Module - Security Settings
# Feature:       Firewall, hardening, and security configuration
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
security_init_callback() {
    field_declare FIREWALL_ENABLE \
        display="Enable Firewall" \
        input=toggle \
        required=true \
        default=true
    
    field_declare FIREWALL_ALLOW_PORTS_TCP \
        display="Allowed TCP Ports (space-separated)" \
        input=string \
        default="22"
    
    field_declare FIREWALL_ALLOW_PORTS_UDP \
        display="Allowed UDP Ports (space-separated)" \
        input=string \
        default=""
    
    field_declare HARDENING_ENABLE \
        display="Apply Security Hardening" \
        input=toggle \
        default=true
    
    field_declare FAIL2BAN_ENABLE \
        display="Enable Fail2Ban" \
        input=toggle \
        default=false
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
security_get_active_fields() {
    local firewall_enable
    firewall_enable=$(config_get "security" "FIREWALL_ENABLE")
    
    echo "FIREWALL_ENABLE"
    
    if [[ "$firewall_enable" == "true" ]]; then
        echo "FIREWALL_ALLOW_PORTS_TCP"
        echo "FIREWALL_ALLOW_PORTS_UDP"
    fi
    
    echo "HARDENING_ENABLE"
    echo "FAIL2BAN_ENABLE"
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
security_validate_extra() {
    # No cross-field validation needed
    return 0
}
