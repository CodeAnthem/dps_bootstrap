# DPS Bootstrap

**Digital Paradise Swarm - Bootstrap Script** - Automated NixOS deployment and configuration system for cluster nodes.

## Purpose

The DPS Bootstrap script is a comprehensive automation tool that transforms a bare NixOS ISO into a fully configured cluster node. It handles disk partitioning, encryption setup, NixOS installation, and flake-based configuration deployment in a single execution.

**What it does:**
- Partitions and formats target disk (with optional LUKS encryption)
- Clones your NixOS flake repository 
- Generates hardware-specific configuration
- Creates host-specific configuration files
- Installs NixOS with your flake configuration
- Sets up networking, users, and system services

## Prerequisites

### System Requirements
- **NixOS ISO**: Boot from official NixOS installation media
- **Network Access**: Internet connection for package downloads and repository cloning
- **Root Access**: Script must run as root user
- **Target Disk**: Available disk for installation (will be completely wiped)

### Repository Requirements
Your flake repository must contain:
- **`flake.nix`**: Main flake with optional hardware input and default nixosConfiguration
- **`templates/` directory**: Role-based configuration templates
  - `tooling.nix` - Management and tooling services
  - `gateway.nix` - Network gateway and routing
  - `worker.nix` - Standard compute worker
  - `gpu-worker.nix` - GPU-accelerated worker
- **`modules/` directory**: Shared NixOS modules
- **`scripts/` directory**: Management and deployment scripts
- **`secrets/` directory**: SOPS encrypted secrets

### GitHub Access
- **Personal Access Token**: Required for private repository access
- **Repository Permissions**: Read access to your flake repository

## Quick Start

### Method 1: Environment Variables + One-liner

```bash
# Boot from NixOS ISO, set root password
passwd

# Configure your deployment (required variables)
export DPS_GIT_REPO="https://github.com/YOUR_USERNAME/YOUR_REPO.git"
export DPS_ROLE="worker"
export DPS_NETWORK_HOSTNAME="worker-01"  
export DPS_NETWORK_ADDRESS="192.168.0.100"

# Optional: Override defaults
export DPS_DISK_TARGET="/dev/nvme0n1"
export DPS_DISK_ENCRYPTION_ENABLED="y"
export DPS_NETWORK_GATEWAY="192.168.0.1"

# Run bootstrap
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bootstrap.sh | bash
```

### Method 2: Configuration File

```bash
# Download and customize config
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/config-example.sh > my-config.sh

# Edit my-config.sh with your values
nano my-config.sh

# Load configuration and run
source my-config.sh
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bootstrap.sh | bash
```

## Features

### Core Functionality
- **One-liner Deployment**: Complete system setup from single command
- **Environment-driven Configuration**: All settings via environment variables
- **Interactive Validation**: Configuration preview and confirmation
- **Robust Error Handling**: Comprehensive validation and retry logic

### Disk Management  
- **Automatic Partitioning**: GPT partition table with EFI boot partition
- **LUKS Encryption**: Optional full-disk encryption with configurable key generation
- **Multiple Key Methods**: urandom, openssl-rand, or manual key entry
- **Flexible Disk Selection**: Configurable target disk (/dev/sda, /dev/nvme0n1, etc.)

### Network Configuration
- **Static IP Assignment**: Configurable IP address and gateway
- **DNS Configuration**: Customizable DNS servers (defaults to 1.1.1.1/1.0.0.1)
- **Role-based Networking**: Different network configs per VM role

### Security Features
- **Secure Token Handling**: GitHub tokens requested interactively (never stored)
- **Key Generation**: Multiple encryption key generation methods
- **Passphrase Protection**: Optional passphrase-based key derivation
- **Credential Cleanup**: Automatic cleanup of temporary credentials

## Flake Integration

### Repository Structure
The bootstrap script expects your flake repository to follow this structure:

```
dps_swarm/                          # Git repository (cloned to /etc/nixos-flake/)
├── flake.nix                       # Main flake with optional hardware input
├── templates/                      # Role-based VM templates
│   ├── tooling.nix                 # Management VM with deployment tools
│   ├── gateway.nix                 # Gateway + Docker Swarm Manager
│   ├── worker.nix                  # Standard worker node
│   └── gpu-worker.nix              # GPU-accelerated worker
├── modules/                        # Shared NixOS modules
│   ├── common.nix                  # Base system configuration
│   ├── docker-swarm.nix            # Docker Swarm setup
│   ├── security.nix                # Security hardening
│   ├── monitoring.nix              # Monitoring stack
│   ├── encryption.nix              # Disk encryption support
│   └── gpu-passthrough.nix         # NVIDIA GPU support
├── scripts/                        # Management scripts
├── secrets/                        # SOPS encrypted secrets
└── lib/                           # Helper functions
```

### Local System Structure (After Bootstrap)
```
/etc/nixos/
├── configuration.nix               # Bootstrap-generated, imports role template
└── hardware-configuration.nix     # Local only, NEVER in repository

/etc/nixos-flake/                   # Git clone of dps_swarm repository
├── [repository contents]
└── .git/

/usr/local/bin/
└── dps-update                      # Update script using --override-input
```

### Flake Requirements
Your `flake.nix` must:
- Use **optional hardware input** with `hardware = { url = "path:/dev/null"; flake = false; }`
- Export `nixosConfigurations.default` that works with hardware override
- Support role-based template system via local configuration imports
- Enable flakes experimental feature
- Work with `--override-input hardware "path:/etc/nixos/hardware-configuration.nix"`

### Template System
Role templates define the base configuration for each node type:
- **tooling**: Management services, monitoring, CI/CD
- **gateway**: Routing, firewall, VPN, load balancing  
- **worker**: Standard compute workloads
- **gpu-worker**: GPU acceleration, ML workloads

### Integration Process
1. **Repository Clone**: Downloads your flake to `/etc/nixos-flake/`
2. **Hardware Detection**: Generates `hardware-configuration.nix` locally in `/etc/nixos/`
3. **Host Configuration**: Creates `/etc/nixos/configuration.nix` importing role template from flake
4. **Flake Installation**: Runs `nixos-install --flake /etc/nixos-flake#default --override-input hardware "path:/mnt/etc/nixos/hardware-configuration.nix"`
5. **Update Script**: Creates `dps-update` script for ongoing configuration management

## Configuration Variables

### Required Variables
- `DPS_GIT_REPO` - Repository URL for your NixOS flake
- `DPS_NETWORK_HOSTNAME` - System hostname
- `DPS_NETWORK_ADDRESS` - Static IP address  
- `DPS_ROLE` - VM role (tooling/gateway/worker/gpu-worker)

### Optional Variables (with defaults)
- `DPS_NETWORK_GATEWAY` - Network gateway (default: 192.168.0.1)
- `DPS_NETWORK_DNS_PRIMARY` - Primary DNS (default: 1.1.1.1)
- `DPS_NETWORK_DNS_SECONDARY` - Secondary DNS (default: 1.0.0.1)
- `DPS_ADMIN_USER` - Admin username (default: admin)
- `DPS_DISK_TARGET` - Target disk (default: /dev/sda)
- `DPS_DISK_ENCRYPTION_ENABLED` - Enable encryption (default: n)
- `DPS_DISK_ENCRYPTION_KEY_LENGTH` - Key length in bytes (default: 32)
- `DPS_DISK_ENCRYPTION_USE_PASSPHRASE` - Use passphrase (default: n)  
- `DPS_DISK_ENCRYPTION_GENERATE` - Key method (default: urandom)

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

After successful bootstrap:
1. **Reboot** the system
2. **Complete Configuration** using tooling VM for secrets management
3. **Update System**: Use `dps-update` command to pull latest configuration
4. **Remove Bootstrap Marker** when production-ready: `rm /etc/bootstrap-phase`

### Update Workflow
Each VM includes an update script that maintains the hardware override:
```bash
# Update system configuration
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
