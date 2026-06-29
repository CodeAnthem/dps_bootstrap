#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       NixOS network configuration generation functions
# ==================================================================================================

# =============================================================================
# NIXOS NETWORK CONFIGURATION GENERATION
# =============================================================================

# Generate NixOS network configuration for Deploy VM
# Usage: create_deploy_network_config "hostname" ["dhcp"|"static"] ["ip_address"] ["gateway"]
create_deploy_network_config() {
    local hostname="$1"
    local network_method="${2:-dhcp}"
    local ip_address="${3:-}"
    local gateway="${4:-192.168.1.1}"
    
    if [[ "$network_method" == "dhcp" ]]; then
        cat << EOF
  networking = {
    hostName = "$hostname";
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH
    };
  };
EOF
    else
        cat << EOF
  networking = {
    hostName = "$hostname";
    interfaces.eth0.ipv4.addresses = [{
      address = "$ip_address";
      prefixLength = 24;
    }];
    defaultGateway = "$gateway";
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH
    };
  };
EOF
    fi
}

# Generate NixOS network configuration for managed node
# Usage: create_node_network_config "hostname" "ip_address" ["gateway"] ["dns_primary"] ["dns_secondary"]
create_node_network_config() {
    local hostname="$1"
    local ip_address="$2"
    local gateway="${3:-192.168.1.1}"
    local dns_primary="${4:-1.1.1.1}"
    local dns_secondary="${5:-1.0.0.1}"
    
    cat << EOF
  networking = {
    hostName = "$hostname";
    interfaces.eth0.ipv4.addresses = [{
      address = "$ip_address";
      prefixLength = 24;
    }];
    defaultGateway = "$gateway";
    nameservers = [ "$dns_primary" "$dns_secondary" ];
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH
    };
  };
EOF
}

# Generate NixOS network configuration from config module
# Usage: nixos_network_from_config "action" "module"
nixos_network_from_config() {
    local action="$1"
    local module="$2"
    
    local hostname
    local method
    local ip
    local gateway
    local dns_primary
    local dns_secondary
    
    hostname=$(config_get "$action" "$module" "HOSTNAME")
    method=$(config_get "$action" "$module" "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        ip=$(config_get "$action" "$module" "IP_ADDRESS")
        gateway=$(config_get "$action" "$module" "NETWORK_GATEWAY")
        dns_primary=$(config_get "$action" "$module" "NETWORK_DNS_PRIMARY")
        dns_secondary=$(config_get "$action" "$module" "NETWORK_DNS_SECONDARY")
        
        create_node_network_config "$hostname" "$ip" "$gateway" "$dns_primary" "$dns_secondary"
    else
        create_deploy_network_config "$hostname" "dhcp"
    fi
}
