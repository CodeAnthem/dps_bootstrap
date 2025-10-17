# Managed Node Setup Guide

**Managed Node specific configuration and roles.**

## 🎯 Managed Node Characteristics

- **📖 Read-Only Access**: Pulls configs from private repository
- **🎭 Role-Based**: worker/gateway/gpu-worker/custom
- **🌐 Static Networking**: Stable IP addresses
- **⚡ Performance Focused**: Optional encryption

## 🎭 Node Roles

### Standard Roles
- **worker**: General compute workloads, Docker containers
- **gateway**: Load balancers, firewalls, VPN endpoints
- **gpu-worker**: ML workloads, GPU acceleration
- **custom**: Your specialized templates

## ⚙️ Managed Node Configuration

### Required
- `DPS_ROLE` - Node role
- `DPS_HOSTNAME` - Node hostname  
- `DPS_IP_ADDRESS` - Static IP address

### Defaults (Managed Node Specific)
```bash
DPS_ENCRYPTION="n"              # Performance over security
DPS_NETWORK_DNS_PRIMARY="1.1.1.1"
DPS_NETWORK_DNS_SECONDARY="1.0.0.1"
```

### Network Configuration (Static Required)
```bash
export DPS_IP_ADDRESS="192.168.1.101"
export DPS_NETWORK_GATEWAY="192.168.1.1"
```

## 🔄 Managed Node Workflow

1. **Role Selection**: Interactive prompt for node role
2. **Repository Clone**: Read-only access to private repo
3. **Hardware Detection**: Generate local hardware config
4. **Flake Install**: Pure flake with hardware override
5. **Update Setup**: Create `dps-update` script

## 🏗️ Post-Installation Structure

```
Managed Node (After Installation)
├── /etc/nixos/
│   ├── configuration.nix           # Imports role template
│   └── hardware-configuration.nix  # Local only
├── /etc/nixos-flake/               # Private repo (read-only)
│   ├── templates/worker.nix        # Role templates
│   └── [private repo contents]
└── /usr/local/bin/dps-update       # Update script
```

## 🔄 Update Mechanism

### Automated Updates
```bash
dps-update  # Pull latest config and rebuild
```

### Manual Process
```bash
cd /etc/nixos-flake
git pull origin main
nixos-rebuild switch --flake .#default \
  --override-input hardware "path:/etc/nixos/hardware-configuration.nix"
```

## 🎯 Role Templates

### Worker Node Template
```nix
# templates/worker.nix
{
  virtualisation.docker.enable = true;
  services.prometheus.exporters.node.enable = true;
  environment.systemPackages = [ docker-compose ];
}
```

### Gateway Node Template  
```nix
# templates/gateway.nix
{
  services.nginx.enable = true;
  services.haproxy.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
```

### GPU Worker Template
```nix
# templates/gpu-worker.nix
{
  services.xserver.videoDrivers = [ "nvidia" ];
  virtualisation.docker.enableNvidia = true;
  environment.systemPackages = [ cudatoolkit ];
}
```

## 🔐 Security Model

### Access Control
- **Read-Only**: Cannot modify infrastructure configs
- **Pull Updates**: Automatic config updates from trusted source
- **SSH Keys**: Managed through Deploy VM or SOPS

### Secret Management
```nix
# In role templates
sops.secrets.database-password = {
  owner = "myapp";
  mode = "0400";
};
```

## 🔍 Managed Node Specific Troubleshooting

**Role Templates**: Ensure template exists in private repository
**Update Issues**: Check flake syntax and hardware override path
**Network**: Verify static IP configuration and gateway

---

For general bootstrap info, see [README.md](README.md). For Deploy VM, see [README_deployVM.md](README_deployVM.md).
