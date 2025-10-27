#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   NixOS Config Builder Module - Network
# Feature:       Generate network configuration blocks
# ==================================================================================================

# =============================================================================
# PUBLIC API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_network_auto() {
    local method
    method=$(nds_config_get "network" "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        local block
        block=$(_nixcfg_network_static \
            "$(nds_config_get "network" "HOSTNAME")" \
            "$(nds_config_get "network" "NETWORK_IP")" \
            "$(nds_config_get "network" "NETWORK_GATEWAY")" \
            "$(nds_config_get "network" "NETWORK_MASK")" \
            "$(nds_config_get "network" "NETWORK_DNS_PRIMARY")" \
            "$(nds_config_get "network" "NETWORK_DNS_SECONDARY")")
    else
        local block
        block=$(_nixcfg_network_dhcp \
            "$(nds_config_get "network" "HOSTNAME")" \
            "$(nds_config_get "network" "NETWORK_DNS_PRIMARY")" \
            "$(nds_config_get "network" "NETWORK_DNS_SECONDARY")")
    fi
    
    nds_nixcfg_register "network" "$block" 20
}

# Manual mode: explicit parameters
nds_nixcfg_network() {
    local method="$1"
    local hostname="$2"
    local ip="${3:-}"
    local gateway="${4:-}"
    local mask="${5:-24}"
    local dns_primary="${6:-1.1.1.1}"
    local dns_secondary="${7:-1.0.0.1}"
    
    local block
    if [[ "$method" == "static" ]]; then
        block=$(_nixcfg_network_static "$hostname" "$ip" "$gateway" "$mask" "$dns_primary" "$dns_secondary")
    else
        block=$(_nixcfg_network_dhcp "$hostname" "$dns_primary" "$dns_secondary")
    fi
    
    nds_nixcfg_register "network" "$block" 20
}

# =============================================================================
# PRIVATE - Implementation Functions
# =============================================================================

_nixcfg_network_static() {
    local hostname="$1"
    local ip="$2"
    local gateway="$3"
    local mask="$4"
    local dns_primary="$5"
    local dns_secondary="$6"
    
    cat <<EOF
networking = {
  hostName = "$hostname";
  interfaces.eth0.ipv4.addresses = [{
    address = "$ip";
    prefixLength = $mask;
  }];
  defaultGateway = "$gateway";
  nameservers = [ "$dns_primary" "$dns_secondary" ];
};
EOF
}

_nixcfg_network_dhcp() {
    local hostname="$1"
    local dns_primary="$2"
    local dns_secondary="$3"
    
    cat <<EOF
networking = {
  hostName = "$hostname";
  networkmanager.enable = true;
  nameservers = [ "$dns_primary" "$dns_secondary" ];
};
EOF
}
