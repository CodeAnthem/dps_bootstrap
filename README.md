# DPS Bootstrap - NixOS Deployment System

> **⚠️ WARNING** - This system is in active development and is not yet ready for production use.
> 
> **⚠️ WARNING** - This system is in active development and is not yet ready for production use.
> 
> **⚠️ WARNING** - This system is in active development and is not yet ready for production use.

**Automated NixOS deployment system** that transforms any NixOS Live ISO into fully configured systems with a single command. This bootstrapper provides a fast, secure, and customizable way to deploy NixOS infrastructure.

## 🎯 Project Purpose

DPS Bootstrap solves the complexity of NixOS deployment by providing:

- **🚀 Rapid Deployment**: Transform bare NixOS ISO to configured system in minutes
- **🔒 Security-First**: Built-in encryption, secure token handling, and access controls
- **🎛️ Flexibility**: Works with any private NixOS flake repository
- **🏗️ Infrastructure Ready**: Deploy management hubs and infrastructure nodes
- **⚙️ Customizable**: Environment variables and interactive configuration

## 🌟 Bootstrapper Benefits

### 📦 Quick NixOS Installation
- **One-liner deployment** from any NixOS Live ISO
- **Interactive configuration** with smart defaults
- **Automated partitioning** with optional LUKS encryption
- **Hardware detection** and configuration generation
- **Flake integration** with pure architecture support

### 🛡️ Security Features
- **LUKS full-disk encryption** with multiple key generation methods
- **Interactive GitHub token input** (never stored or logged)
- **Automatic credential cleanup** after operations
- **Repository integrity verification** and untracked file detection
- **SSH key generation** and secure distribution

### 🔧 Deploy VM Management Hub

The Deploy VM provides centralized infrastructure management:

- **🔑 SOPS Integration**: Centralized secret management for entire infrastructure
- **📡 SSH Orchestration**: Automated key distribution and node access
- **🚀 Mass Deployment**: Deploy multiple nodes from templates
- **📊 Monitoring Integration**: Built-in system monitoring and logging
- **🔄 Update Management**: Coordinate updates across infrastructure
- **💾 Backup Systems**: Automated backup of keys and configurations

## 📋 Private Repository Requirements

Your private NixOS flake repository must include:

```nix
# flake.nix - Required structure
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Optional hardware input for pure flake architecture
    hardware = { url = "path:/dev/null"; flake = false; };
  };

  outputs = { nixpkgs, hardware, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      modules = [
        # Hardware configuration override
        (if hardware != null then hardware else {})
        # Your system configuration
        ./configuration.nix
      ];
    };
  };
}
```

**Required Components**:
- **flake.nix**: Pure flake with hardware input support
- **configuration.nix**: Base system configuration
- **templates/**: Role-based configurations (optional)
- **secrets/**: SOPS encrypted secrets (optional)

## 📋 Prerequisites

- **NixOS ISO**: Official NixOS installation media
- **Network**: Internet connection for downloads
- **Target Disk**: Available storage device (will be completely wiped)
- **Private Repository**: NixOS flake repository (optional for Deploy VM setup)
- **GitHub Token**: Personal Access Token for private repository access

## 🚀 Quick Start

1. Prepare the target machine
- Live boot from **Minimal NixOS ISO** from https://nixos.org/download/

2. (optional) Set user password to allow SSH login
- `passwd`
- Login via SSH client

3. **Recommended**: Run the one-liner
```bash
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/start.sh | bash
```
**DEV**: Run the one-liner
```bash
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/start.sh | bash -s -- --dev
```

3. **Manual**: Clone and run the main script
```bash
# 1. Clone Repo
git clone https://github.com/codeAnthem/dps_bootstrap.git /tmp/dps_bootstrap
cd /tmp/dps_bootstrap
# 2. Execute Main Script
sudo bash bootstrap/main.sh
```

## 📚 What is the script workflow?

### start.sh (Quicks Start one-liner script) will:
1. **Download** this repository to `/tmp/dps_bootstrap/`
2. **Verify Purity** it will force reset the repository to the latest commit
3. **Avoid manipulation** checks and warns about (potential unwanted) untracked files
4. **Launch** the interactive bootstrap selector 

### bootstrap/main.sh (Main bootstrap script) will:
1. **Source** all library scripts
2. **Check** root privileges
3. **Create** runtime directory (where secrets are temporarily stored)$
4. **Setup** Cleanup Trap  to purge runtime files
5. **Grab** bootstrap mode files
6. **Menu** Prompt to select the bootstrap action
7. **Execute** the selected bootstrap action
8. **Cleanup** runtime directory

___

## Bootstraper Modes:

### 🎯 Deploy VM (Management Hub)
- **Purpose**: Central management and deployment system
- **Access**: Write access to your private NixOS flake repository
- **Features**: SOPS key management, SSH orchestration, cluster deployment tools
- **Security**: Encrypted by default, stateless and recoverable
-> Read More: [deployVM.md](bootstrap/README_deployVM.md)

### 🔧 Managed Nodes (Infrastructure)
- **Purpose**: Any NixOS configuration from your private flake
- **Access**: Read-only access to your private repository
- **Types**: Servers, workstations, IoT devices, containers, custom systems
- **Updates**: Automated configuration pulls and system updates
-> Read More: [managedNode.md](bootstrap/README_managedNode.md)




## 📚 Documentation

- **[bootstrap/README.md](bootstrap/README.md)** - Bootstrap script documentation
- **[deployVM/README.md](deployVM/README.md)** - Deploy VM NixOS configuration details

## ⚙️ Configuration

The system uses **smart defaults** with optional customization:

### Deploy VM Defaults
- **Encryption**: Enabled by default
- **Networking**: DHCP (configurable to static)
- **Role**: Management and deployment hub

### Managed Node Defaults  
- **Encryption**: Optional (disabled by default)
- **Networking**: Static IP required
- **Role**: Configurable (worker/gateway/gpu-worker/custom)



## 🆘 Support

- **Debug Mode**: Set `export DPS_DEBUG=1` for verbose logging
- **Common Issues**: Check disk paths, network configuration, and repository access
- **Repository Structure**: Ensure your private flake follows NixOS conventions

## 📄 License

This project is open source. See individual files for specific license information.

---

**Ready to deploy?** Run the one-liner above and let DPS Bootstrap handle the rest! 🚀
