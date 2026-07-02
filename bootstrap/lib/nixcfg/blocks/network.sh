#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-02
# Description:   NixOS Config Generation - Network Module
# Feature:       Network configuration (DHCP, static IP, hostname, DNS)
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_network_auto() {
    local hostname method ip gateway dns1 dns2 mask_val prefix
    hostname=$(nds_config_get "network" "NETWORK_HOSTNAME")
    method=$(nds_config_get "network" "NETWORK_METHOD")
    ip=$(nds_config_get "network" "NETWORK_IP")
    gateway=$(nds_config_get "network" "NETWORK_GATEWAY")
    dns1=$(nds_config_get "network" "NETWORK_DNS_PRIMARY")
    dns2=$(nds_config_get "network" "NETWORK_DNS_SECONDARY")
    mask_val=$(nds_config_get "network" "NETWORK_MASK")

    if [[ "$method" == "static" ]]; then
        prefix=$(_nixcfg_netmask_to_prefix "$mask_val")
        _nixcfg_network_static "$hostname" "$ip" "$gateway" "$prefix" "$dns1" "$dns2"
    else
        _nixcfg_network_dhcp "$hostname" "$dns1" "$dns2"
    fi
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

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

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

    local ns_line=""
    if [[ -n "$dns_primary" || -n "$dns_secondary" ]]; then
        ns_line=$'\n  nameservers = [ "'"$dns_primary"'" "'"$dns_secondary"'" ];'
    fi

    # Match any wired NIC via systemd-networkd instead of a fixed name — "eth0"
    # does not exist on predictable-name systems (ens33, enp0s3, …), so the
    # static address would never be applied.
    local block
    block=$(cat <<EOF
networking = {
  hostName = "$hostname";
  useDHCP = false;${ns_line}
};
systemd.network.enable = true;
systemd.network.networks."10-wired" = {
  matchConfig.Type = "ether";
  address = [ "$ip/$mask" ];
  gateway = [ "$gateway" ];
  linkConfig.RequiredForOnline = "routable";
};
EOF
)

    nds_nixcfg_register "network" "$block" 20
}

_nixcfg_network_dhcp() {
    local hostname="$1"
    local dns_primary="$2"
    local dns_secondary="$3"

    local remote_unlock ns_line=""
    remote_unlock=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_UNLOCK" 2>/dev/null || true)
    if [[ -n "$dns_primary" || -n "$dns_secondary" ]]; then
        ns_line=$'\n  nameservers = [ "'"$dns_primary"'" "'"$dns_secondary"'" ];'
    fi

    local block
    if [[ "$remote_unlock" == "true" ]]; then
        # Remote unlock needs a predictable IP. Drive the booted system with
        # systemd-networkd and a MAC-based DHCP client id so it presents the
        # same identity as the initrd (see remoteUnlock.sh) — the DHCP server
        # then hands out the SAME lease in the initrd and after boot, so the
        # initrd is reachable on the machine's normal address.
        block=$(cat <<EOF
networking = {
  hostName = "$hostname";
  useDHCP = false;${ns_line}
};
systemd.network.enable = true;
systemd.network.networks."10-wired" = {
  matchConfig.Type = "ether";
  networkConfig.DHCP = "ipv4";
  dhcpV4Config.ClientIdentifier = "mac";
  linkConfig.RequiredForOnline = "routable";
};
EOF
)
    else
        block=$(cat <<EOF
networking = {
  hostName = "$hostname";
  networkmanager.enable = true;${ns_line}
};
EOF
)
    fi

    nds_nixcfg_register "network" "$block" 20
}

_nixcfg_netmask_to_prefix() {
    local mask="$1"
    case "$mask" in
        255.255.255.0|255.255.255.0/24|/24|24) echo 24 ;;
        255.255.0.0|16) echo 16 ;;
        255.0.0.0|8) echo 8 ;;
        */*) echo "${mask##*/}" ;;
        *) echo 24 ;;
    esac
}
