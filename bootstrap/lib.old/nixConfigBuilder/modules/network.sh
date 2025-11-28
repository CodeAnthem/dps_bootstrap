#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   NixOS Config Generation - Network Module
# Feature:       Network configuration (DHCP, static IP, hostname, DNS)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# NIXOS CONFIG GENERATION - Public API
# ----------------------------------------------------------------------------------

# Auto-mode: reads from configuration modules
nds_nixcfg_network_auto() {
    local hostname method ip gateway dns1 dns2
    hostname=$(nds_config_get "network" "HOSTNAME")
    method=$(nds_config_get "network" "NETWORK_METHOD")
    ip=$(nds_config_get "network" "IP_ADDRESS")
    gateway=$(nds_config_get "network" "GATEWAY")
    dns1=$(nds_config_get "network" "DNS_PRIMARY")
    dns2=$(nds_config_get "network" "DNS_SECONDARY")
    
    _nixcfg_network_generate "$hostname" "$method" "$ip" "$gateway" "$dns1" "$dns2"
}

# Manual mode: explicit parameters
nds_nixcfg_network() {
    local hostname="$1"
    local method="${2:-dhcp}"
    local ip="${3:-}"
    local gateway="${4:-}"
    local dns1="${5:-1.1.1.1}"
    local dns2="${6:-1.0.0.1}"
    
    _nixcfg_network_generate "$hostname" "$method" "$ip" "$gateway" "$dns1" "$dns2"
}

# ----------------------------------------------------------------------------------
# NIXOS CONFIG GENERATION - Implementation
# ----------------------------------------------------------------------------------

_nixcfg_network_generate() {
    local hostname="$1"
    local method="$2"
    local ip="$3"
    local gateway="$4"
    local dns1="$5"
    local dns2="$6"
    
    if [[ "$method" == "static" ]]; then
        # Extract mask from IP (e.g., 192.168.1.10/24 -> 24)
        local mask="${ip##*/}"
        local ip_only="${ip%/*}"
        _nixcfg_network_static "$hostname" "$ip_only" "$gateway" "$mask" "$dns1" "$dns2"
    else
        _nixcfg_network_dhcp "$hostname" "$dns1" "$dns2"
    fi
}

_nixcfg_network_static() {
    local hostname="$1"
    local ip="$2"
    local gateway="$3"
    local mask="$4"
    local dns_primary="$5"
    local dns_secondary="$6"
    
    local block
    # Only include nameservers if at least one is set
    if [[ -n "$dns_primary" || -n "$dns_secondary" ]]; then
        block=$(cat <<EOF
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
)
    else
        block=$(cat <<EOF
networking = {
  hostName = "$hostname";
  interfaces.eth0.ipv4.addresses = [{
    address = "$ip";
    prefixLength = $mask;
  }];
  defaultGateway = "$gateway";
};
EOF
)
    fi
    
    nds_nixcfg_register "network" "$block" 20
}

_nixcfg_network_dhcp() {
    local hostname="$1"
    local dns_primary="$2"
    local dns_secondary="$3"
    
    local block
    # Only include nameservers if at least one is set
    if [[ -n "$dns_primary" || -n "$dns_secondary" ]]; then
        block=$(cat <<EOF
networking = {
  hostName = "$hostname";
  networkmanager.enable = true;
  nameservers = [ "$dns_primary" "$dns_secondary" ];
};
EOF
)
    else
        block=$(cat <<EOF
networking = {
  hostName = "$hostname";
  networkmanager.enable = true;
};
EOF
)
    fi
    
    nds_nixcfg_register "network" "$block" 20
}
