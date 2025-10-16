#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Network Setup Helper Functions
# ==================================================================================================

# =============================================================================
# NETWORK CONFIGURATION FUNCTIONS
# =============================================================================

create_deploy_network_config() {
    local hostname="$1"
    local network_method="${DPS_NETWORK_METHOD:-dhcp}"
    local ip_address="${DPS_IP_ADDRESS:-}"
    local gateway="${DPS_NETWORK_GATEWAY:-192.168.1.1}"
    
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

create_node_network_config() {
    local hostname="$1"
    local ip_address="${DPS_IP_ADDRESS}"
    local gateway="${DPS_NETWORK_GATEWAY:-192.168.1.1}"
    local dns_primary="${DPS_NETWORK_DNS_PRIMARY:-1.1.1.1}"
    local dns_secondary="${DPS_NETWORK_DNS_SECONDARY:-1.0.0.1}"
    
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

# =============================================================================
# SSH KEY MANAGEMENT
# =============================================================================

generate_ssh_key() {
    local key_file="$1"
    local passphrase="$2"
    local hostname="$3"
    
    log "Generating SSH key: $key_file"
    
    mkdir -p "$(dirname "$key_file")"
    
    if [[ -n "$passphrase" ]]; then
        with_nix_shell "openssh" "ssh-keygen -t ed25519 -f '$key_file' -N '$passphrase' -C 'dps-admin@$hostname'"
    else
        with_nix_shell "openssh" "ssh-keygen -t ed25519 -f '$key_file' -N '' -C 'dps-admin@$hostname'"
    fi
    
    chmod 600 "$key_file"
    chmod 644 "${key_file}.pub"
    
    # Return public key
    cat "${key_file}.pub"
}

# =============================================================================
# AGE KEY MANAGEMENT
# =============================================================================

generate_age_key() {
    local key_file="$1"
    log "Generating Age key: $key_file"
    
    mkdir -p "$(dirname "$key_file")"
    with_nix_shell "age" "age-keygen -o '$key_file'"
    chmod 600 "$key_file"
    
    # Extract public key
    local public_key
    public_key=$(grep "public key:" "$key_file" | cut -d: -f2 | tr -d ' ')
    echo "$public_key"
}
