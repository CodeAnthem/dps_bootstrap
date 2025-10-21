#!/usr/bin/env bash
# ==================================================================================================
# File:          validation_unused.sh
# Description:   Validation functions that are currently unused but kept for potential future use
# Author:        DPS Project
# ==================================================================================================
# NOTE: This file is NOT sourced by default. Functions here are for reference only.
# ==================================================================================================

# Legacy validation functions from old validation.sh that validate entire configurations
# These are replaced by the new modular callback-based validation system

# Validate deploy configuration (LEGACY - use module callbacks instead)
validate_deploy_config() {
    local errors=()
    
    # Required fields
    [[ -z "${DPS_HOSTNAME:-}" ]] && errors+=("DPS_HOSTNAME is required")
    
    # Validate hostname if provided
    if [[ -n "${DPS_HOSTNAME:-}" ]] && ! validate_hostname "$DPS_HOSTNAME"; then
        errors+=("Invalid hostname format: $DPS_HOSTNAME")
    fi
    
    # Validate IP if static networking
    if [[ "${DPS_NETWORK_METHOD:-dhcp}" == "static" ]]; then
        [[ -z "${DPS_IP_ADDRESS:-}" ]] && errors+=("DPS_IP_ADDRESS is required for static networking")
        if [[ -n "${DPS_IP_ADDRESS:-}" ]] && ! validate_ip "$DPS_IP_ADDRESS"; then
            errors+=("Invalid IP address format: $DPS_IP_ADDRESS")
        fi
    fi
    
    # Validate gateway IP if provided
    if [[ -n "${DPS_NETWORK_GATEWAY:-}" ]] && ! validate_ip "$DPS_NETWORK_GATEWAY"; then
        errors+=("Invalid gateway IP format: $DPS_NETWORK_GATEWAY")
    fi
    
    # Validate disk
    if [[ -n "${DPS_DISK_TARGET:-}" ]] && ! validate_disk "$DPS_DISK_TARGET"; then
        errors+=("Disk not found or not a block device: $DPS_DISK_TARGET")
    fi
    
    # Validate encryption setting
    if [[ -n "${DPS_ENCRYPTION:-}" ]] && [[ "$DPS_ENCRYPTION" != "y" && "$DPS_ENCRYPTION" != "n" ]]; then
        errors+=("Encryption setting must be 'y' or 'n', got: $DPS_ENCRYPTION")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        error "Deploy VM configuration validation failed:\n$(printf "  %s\n" "${errors[@]}")"
    fi
}

# Validate node configuration (LEGACY - use module callbacks instead)
validate_node_config() {
    local errors=()
    
    # Required fields
    [[ -z "${DPS_ROLE:-}" ]] && errors+=("DPS_ROLE is required")
    [[ -z "${DPS_HOSTNAME:-}" ]] && errors+=("DPS_HOSTNAME is required")
    [[ -z "${DPS_IP_ADDRESS:-}" ]] && errors+=("DPS_IP_ADDRESS is required")
    
    # Validate role
    if [[ -n "${DPS_ROLE:-}" ]] && ! validate_role "$DPS_ROLE"; then
        errors+=("Invalid role: $DPS_ROLE. Must be one of: worker, gateway, gpu-worker")
    fi
    
    # Validate hostname
    if [[ -n "${DPS_HOSTNAME:-}" ]] && ! validate_hostname "$DPS_HOSTNAME"; then
        errors+=("Invalid hostname format: $DPS_HOSTNAME")
    fi
    
    # Validate IP address
    if [[ -n "${DPS_IP_ADDRESS:-}" ]] && ! validate_ip "$DPS_IP_ADDRESS"; then
        errors+=("Invalid IP address format: $DPS_IP_ADDRESS")
    fi
    
    # Validate gateway IP
    if [[ -n "${DPS_NETWORK_GATEWAY:-}" ]] && ! validate_ip "$DPS_NETWORK_GATEWAY"; then
        errors+=("Invalid gateway IP format: $DPS_NETWORK_GATEWAY")
    fi
    
    # Validate DNS IPs
    if [[ -n "${DPS_NETWORK_DNS_PRIMARY:-}" ]] && ! validate_ip "$DPS_NETWORK_DNS_PRIMARY"; then
        errors+=("Invalid primary DNS IP format: $DPS_NETWORK_DNS_PRIMARY")
    fi
    
    if [[ -n "${DPS_NETWORK_DNS_SECONDARY:-}" ]] && ! validate_ip "$DPS_NETWORK_DNS_SECONDARY"; then
        errors+=("Invalid secondary DNS IP format: $DPS_NETWORK_DNS_SECONDARY")
    fi
    
    # Validate disk
    if [[ -n "${DPS_DISK_TARGET:-}" ]] && ! validate_disk "$DPS_DISK_TARGET"; then
        errors+=("Disk not found or not a block device: $DPS_DISK_TARGET")
    fi
    
    # Validate encryption setting
    if [[ -n "${DPS_ENCRYPTION:-}" ]] && [[ "$DPS_ENCRYPTION" != "y" && "$DPS_ENCRYPTION" != "n" ]]; then
        errors+=("Encryption setting must be 'y' or 'n', got: $DPS_ENCRYPTION")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        error "Managed node configuration validation failed:\n$(printf "  %s\n" "${errors[@]}")"
    fi
}
