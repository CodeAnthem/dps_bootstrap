# DPS Bootstrap - NixOS Deployment System

**Public repository for deploying and managing NixOS infrastructure** - Complete automation system with Deploy VM and managed node architecture.

## Project Architecture

This repository provides a **generic NixOS deployment system** that works with any private NixOS flake repository. The system consists of two main components:

1. **`dps_bootstrap`** (this repo - public): Deploy VM configuration and bootstrap tooling
2. **`your-private-repo`** (private): Your NixOS configurations, secrets, and templates

### System Overview

**Deploy VM:**
- Management and deployment hub for your infrastructure
- Encrypted and stateless (recoverable from backups)
- Write access to your private NixOS flake repository
- Manages SOPS keys, SSH keys, and infrastructure secrets
- Orchestrates deployment and updates of managed nodes

**Managed Nodes:**
- Any NixOS configuration from your private flake (servers, workstations, IoT devices, etc.)
- Read-only access to your private repository
- Pull configurations and updates from your private repo
- Managed and orchestrated by Deploy VM

### Flexibility & Use Cases
This system is **not limited to any specific use case**. It can deploy:
- **Server Infrastructure**: Web servers, databases, monitoring systems
- **Container Orchestration**: Docker Swarm, Kubernetes nodes, standalone containers  
- **Development Environments**: Development workstations, CI/CD runners
- **IoT & Edge**: Raspberry Pi clusters, edge computing nodes
- **Desktop Systems**: Managed workstations with centralized configuration
- **Custom Solutions**: Any NixOS configuration you can define in a flake

## Current Implementation Plan

### Repository Structure
```
dps_bootstrap/                      # Public repository
├── README.md                       # This comprehensive guide
├── bootstrap.sh                    # Main entry point with embedded workflows
├── deployVM/                       # Deploy VM configuration  
│   ├── configuration.nix           # Deploy VM NixOS config (no secrets)
│   └── hardware-template.nix       # Hardware template
├── lib/                            # Script libraries
│   └── ...                         # Helper functions
├── deployTools/                    # Deploy VM management scripts
│   ├── cluster-deploy.sh           # Mass deployment
│   ├── node-manage.sh              # Single node operations  
│   ├── secrets-sync.sh             # Sync secrets from private repo
│   └── backup-keys.sh              # Backup essential keys
└── examples/                       # Configuration examples
    ├── deploy-vm-vars.sh           # Deploy VM environment variables
    └── node-configs/               # Node configuration examples
```

### Bootstrap Script Design

**Unified Entry Point:**
- Single `bootstrap.sh` script with interactive mode selection
- One-liner compatible: `curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh | bash`
- Interactive menu asks user to choose between Deploy VM or Cluster Node setup
- No mode parameters needed in the one-liner call

**Shared Library Approach:**
- Common functions (logging, validation, disk setup) in `scripts/common-functions.sh`
- Mode-specific logic in dedicated scripts (`bootstrap-deploy.sh`, `bootstrap-node.sh`)
- Dynamic loading of required functions to avoid code duplication
- Cleanup of temporary files after execution

**Configuration Strategy:**
- Each workflow (Deploy VM vs Node) has separate default values
- Environment variables can override defaults (same as current system)
- Interactive validation: script shows current values and asks for confirmation/changes
- Smart defaults per workflow:
  - Deploy VM: Encryption=yes by default, DHCP networking option
  - Cluster Node: Encryption=optional, static IP required

**Architecture Decision - Bootstrap Script Structure:**

**Chosen Approach: Hybrid - Helper Libraries + Embedded Workflows**
- **Helper functions in separate files**: `lib/common.sh`, `lib/disk-setup.sh`, etc. (maintainable)
- **Main workflow logic in bootstrap.sh**: Compact workflows since helpers do heavy lifting
- **Single entry point**: One bootstrap.sh that sources helpers and contains both workflows
- **Benefits**: Maintainable code, single file distribution, shared functions, no duplication

**Configuration Strategy (Answered):**
- Each workflow (Deploy VM vs Node) has separate default values
- Interactive validation shows current values and asks for confirmation/changes  
- Smart defaults per workflow (Deploy VM: encryption=yes, DHCP networking; Nodes: encryption=optional, static IP)
- Environment variables can override defaults but script always confirms before proceeding

## Purpose

The DPS Bootstrap system transforms a bare NixOS Live ISO into either:
1. **Deploy VM**: Management system with deployment tools and write access to your private flake
2. **Managed Node**: Any NixOS system defined in your private flake with read-only access

**What it does:**
- Interactive mode selection (Deploy VM or Managed Node)
- Partitions and formats target disk (with optional LUKS encryption)
- Clones appropriate repositories (public tools + your private configurations)
- Generates hardware-specific configuration
- Creates host-specific configuration files
- Installs NixOS with your flake configuration
- Sets up networking, users, and system services
- Configures access permissions and update mechanisms

## Prerequisites

### System Requirements
- **NixOS ISO**: Boot from official NixOS installation media
- **Network Access**: Internet connection for package downloads and repository cloning
- **Root Access**: Script must run as root user
- **Target Disk**: Available disk for installation (will be completely wiped)

### Repository Access
- **Personal Access Token**: Required for private repository access
- **Deploy VM**: Needs write access to your private NixOS flake repository
- **Managed Nodes**: Need read-only access to your private NixOS flake repository

### Private Repository Requirements
Your private NixOS flake repository must have:
- **`flake.nix`**: With optional hardware input and default nixosConfiguration
- **Templates or configurations**: For your various node types
- **SOPS secrets** (optional): For encrypted configuration data
- **Minimal structure**: The system is flexible and works with most flake layouts

## Quick Start

### Interactive One-liner (Recommended)

```bash
# Boot from NixOS ISO, set root password
passwd

# Run interactive bootstrap - script will ask for mode selection
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/main.sh | bash
```

The script will:
1. Ask whether you want to create a Deploy VM or Cluster Node
2. Show current configuration values (with smart defaults per mode)
3. Allow you to modify any values before proceeding
4. Handle all setup automatically

### Advanced: Pre-configured Environment Variables

```bash
# Deploy VM setup with custom values
export DPS_HOSTNAME="deploy-01"
export DPS_DISK_TARGET="/dev/nvme0n1"
export DPS_NETWORK_METHOD="dhcp"  # or "static"
export DPS_ENCRYPTION="y"  # default for Deploy VM

# Cluster Node setup with custom values  
export DPS_ROLE="worker"
export DPS_HOSTNAME="worker-01"  
export DPS_IP_ADDRESS="192.168.1.100"
export DPS_ENCRYPTION="n"  # optional for nodes

# Run bootstrap (will still show interactive confirmation)
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh | bash
```

## Features

### Core Functionality
- **Interactive Mode Selection**: Choose Deploy VM or Managed Node setup
- **One-liner Deployment**: Complete system setup from single command
- **Smart Defaults**: Different default values per deployment mode
- **Interactive Validation**: Shows current config, allows modifications
- **Robust Error Handling**: Comprehensive validation and retry logic

### Deploy VM Features
- **Management Hub**: Complete deployment and management tooling
- **Write Access**: Full access to your private repository for infrastructure management
- **SOPS Integration**: Manages encryption keys and secrets for your entire infrastructure
- **Stateless Design**: Encrypted and recoverable from key backups
- **Network Flexibility**: Supports both DHCP and static IP configuration

### Managed Node Features  
- **Flexible Configurations**: Any NixOS system defined in your private flake
- **Read-only Access**: Pulls configurations from your private repository
- **Hardware Override**: Pure flake architecture with local hardware configs
- **Update Mechanism**: Automated update scripts with rollback capability

### Disk Management  
- **Automatic Partitioning**: GPT partition table with EFI boot partition
- **LUKS Encryption**: Optional full-disk encryption (default on Deploy VM)
- **Multiple Key Methods**: urandom, openssl-rand, or manual key entry
- **Flexible Disk Selection**: Configurable target disk (/dev/sda, /dev/nvme0n1, etc.)

### Network Configuration
- **Flexible Networking**: DHCP or static IP assignment per deployment type
- **DNS Configuration**: Customizable DNS servers (defaults to 1.1.1.1/1.0.0.1)
- **Role-based Networking**: Different network configs per VM role

### Security Features
- **Secure Token Handling**: GitHub tokens requested interactively (never stored)
- **Access Control**: Deploy VM gets write access, nodes get read-only access
- **Key Generation**: Multiple encryption key generation methods
- **Credential Cleanup**: Automatic cleanup of temporary credentials

## Repository Integration

### Deploy VM Integration
**Deploy VM Setup:**
1. **Public Repo Clone**: Downloads `dps_bootstrap` to `/tmp` for tooling
2. **Deploy VM Config**: Uses `deployVM/configuration.nix` from this repository
3. **Private Repo Access**: Configures write access to `dps_swarm` repository
4. **Tool Installation**: Installs deployment and management tools
5. **Key Management**: Sets up SOPS keys and SSH access for cluster management

**Deploy VM Structure (After Bootstrap):**
```
/etc/nixos/
├── configuration.nix               # Based on deployVM/configuration.nix
└── hardware-configuration.nix     # Local hardware config

/opt/dps-tools/                     # Deployment tooling (from this repo)
├── cluster-deploy.sh               # Mass deployment scripts
├── node-manage.sh                  # Individual node management
└── secrets-sync.sh                 # Secret management tools

/var/lib/dps-swarm/                 # Private repo clone (write access)
├── [dps_swarm repository contents]
└── .git/
```

### Cluster Node Integration  
**Cluster Node Setup:**
1. **Private Repo Clone**: Downloads `dps_swarm` to `/etc/nixos-flake/` (read-only)
2. **Hardware Detection**: Generates `hardware-configuration.nix` locally
3. **Role Configuration**: Creates local config importing role template from `dps_swarm`
4. **Pure Flake Install**: Uses hardware override mechanism
5. **Update Script**: Creates `dps-update` script for ongoing updates

**Cluster Node Structure (After Bootstrap):**
```
/etc/nixos/
├── configuration.nix               # Imports role template from dps_swarm
└── hardware-configuration.nix     # Local only, NEVER in repository

/etc/nixos-flake/                   # Git clone of dps_swarm repository (read-only)
├── flake.nix                       # Pure flake with optional hardware input
├── templates/                      # Role-based VM templates
├── modules/                        # Shared NixOS modules
├── secrets/                        # SOPS encrypted secrets
└── [other dps_swarm contents]

/usr/local/bin/
└── dps-update                      # Update script using --override-input
```

### Flake Requirements (dps_swarm repository)
The private `dps_swarm` repository must:
- Use **optional hardware input** with `hardware = { url = "path:/dev/null"; flake = false; }`
- Export `nixosConfigurations.default` that works with hardware override
- Support role-based template system via local configuration imports
- Enable flakes experimental feature
- Work with `--override-input hardware "path:/etc/nixos/hardware-configuration.nix"`

### Template System (dps_swarm repository)
Role templates define the base configuration for each node type:
- **worker**: Standard compute workloads
- **gateway**: Routing, firewall, VPN, load balancing  
- **gpu-worker**: GPU acceleration, ML workloads
- **[custom roles]**: Additional specialized node types

## Configuration Variables

### Deploy VM Variables
**Required:**
- `DPS_HOSTNAME` - Deploy VM hostname (e.g., "deploy-01")

**Optional (with smart defaults):**
- `DPS_NETWORK_METHOD` - "dhcp" or "static" (default: dhcp)
- `DPS_IP_ADDRESS` - Static IP if using static method
- `DPS_NETWORK_GATEWAY` - Network gateway (default: 192.168.1.1)
- `DPS_ENCRYPTION` - Enable encryption (default: y for Deploy VM)
- `DPS_DISK_TARGET` - Target disk (default: /dev/sda)
- `DPS_ADMIN_USER` - Admin username (default: admin)

### Cluster Node Variables  
**Required:**
- `DPS_ROLE` - Node role (worker/gateway/gpu-worker)
- `DPS_HOSTNAME` - Node hostname (e.g., "worker-01")
- `DPS_IP_ADDRESS` - Static IP address for the node

**Optional (with smart defaults):**
- `DPS_NETWORK_GATEWAY` - Network gateway (default: 192.168.1.1)
- `DPS_NETWORK_DNS_PRIMARY` - Primary DNS (default: 1.1.1.1)
- `DPS_NETWORK_DNS_SECONDARY` - Secondary DNS (default: 1.0.0.1)
- `DPS_ENCRYPTION` - Enable encryption (default: n for nodes)
- `DPS_DISK_TARGET` - Target disk (default: /dev/sda)
- `DPS_ADMIN_USER` - Admin username (default: admin)

### Shared Variables
- `DPS_DISK_ENCRYPTION_KEY_LENGTH` - Key length in bytes (default: 32)
- `DPS_DISK_ENCRYPTION_USE_PASSPHRASE` - Use passphrase (default: n)  
- `DPS_DISK_ENCRYPTION_GENERATE` - Key method (default: urandom)
- `DPS_DEBUG` - Enable debug logging (default: 0)

## Advanced Features

### Security & Performance
- **Runtime Isolation**: Unique temporary directories per execution
- **Credential Security**: Interactive token input, automatic cleanup
- **Input Validation**: IP addresses, hostnames, disk paths validation
- **Performance Optimized**: Uses `printf` instead of `date` for timestamps
- **Error Recovery**: Retry loops for user input, comprehensive error handling

### System Integration  
- **Flakes Enabled**: Automatically enables Nix experimental features
- **Dynamic Versioning**: Auto-detects NixOS version for `system.stateVersion`
- **Two-phase Deployment**: Bootstrap phase marker for staged configuration
- **Hardware Detection**: Automatic hardware configuration generation

### Encryption Methods
- **urandom** (default): Linux `/dev/urandom` entropy
- **openssl-rand**: OpenSSL CSPRNG via nix-shell
- **manual**: User-provided encryption key

## Post-Installation

### Deploy VM Post-Installation
After successful Deploy VM bootstrap:
1. **Reboot** the system
2. **Clone dps_swarm**: Set up write access to private repository
3. **Generate Keys**: Create SOPS keys and SSH keys for cluster management
4. **Deploy Nodes**: Use deployment tools to create cluster nodes
5. **Manage Cluster**: Use management tools for ongoing operations

### Cluster Node Post-Installation  
After successful cluster node bootstrap:
1. **Reboot** the system
2. **Join Cluster**: Node automatically joins Docker Swarm (if applicable)
3. **Verify Connectivity**: Ensure node can communicate with Deploy VM
4. **Update System**: Use `dps-update` command to pull latest configuration

### Update Workflows

**Deploy VM Updates:**
```bash
# Update deployment tooling
cd /opt/dps-tools
git pull origin main
sudo ./update-tools.sh

# Update cluster configurations
cd /var/lib/dps-swarm  
git pull origin main
# Push any local changes back to repository
```

**Cluster Node Updates:**
```bash
# Update system configuration (maintains hardware override)
dps-update

# Manual update process
cd /etc/nixos-flake
git pull origin main
nixos-rebuild switch --flake .#default --override-input hardware "path:/etc/nixos/hardware-configuration.nix"
```

## Troubleshooting

### Common Issues
- **Disk not found**: Verify `DPS_DISK_TARGET` points to correct device
- **Network issues**: Check IP address conflicts and gateway configuration  
- **Repository access**: Ensure GitHub token has read permissions
- **Flake errors**: Verify repository structure matches requirements

### Debug Mode
Enable debug logging:
```bash
export DPS_DEBUG=1
```

## Security Considerations

- **Never commit tokens**: GitHub tokens are requested interactively
- **Backup encryption keys**: Keys are displayed once during setup
- **Network security**: Uses HTTPS for all repository operations
- **Minimal attack surface**: Temporary credentials, automatic cleanup
