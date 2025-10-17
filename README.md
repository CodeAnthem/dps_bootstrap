# DPS Bootstrap - NixOS Deployment System

**WARNING** ⚠️  - __This system is in active development and is not yet ready for production use.__

**WARNING** ⚠️  - __This system is in active development and is not yet ready for production use.__

**WARNING** ⚠️  - __This system is in active development and is not yet ready for production use.__


**Automated NixOS deployment system** - Transform any NixOS Live ISO into a Deploy VM management hub or managed infrastructure node with a single command.
All settings can be customized through environment variables or interactive prompts.

## 🛡️ Security Features

- **🔐 Secure Tokens**: Interactive GitHub token input (never stored)
- **🔑 Encryption**: LUKS full-disk encryption with multiple key methods
- **🚫 Access Control**: Deploy VM (write) vs Managed Nodes (read-only)
- **🧹 Cleanup**: Automatic credential and temporary file cleanup
- **🔍 Integrity**: Repository verification and untracked file detection

## 🎨 System Architecture

This repository provides **generic deployment tooling** that works with **any private NixOS flake repository**:

```
┌─────────────────┐    ┌──────────────────────┐
│  dps_bootstrap  │    │  your-private-repo   │
│   (this repo)   │    │   (your NixOS configs)│
│                 │    │                      │
│ • Bootstrap     │────▶│ • Flake configs     │
│ • Deploy VM     │    │ • Node templates    │
│ • Tooling       │    │ • Secrets (SOPS)    │
│ • Libraries     │    │ • Custom modules    │
└─────────────────┘    └──────────────────────┘
```

## 📋 Prerequisites

- **NixOS ISO**: Official NixOS installation media
- **Network**: Internet connection for downloads
- **Disk**: Available storage device (will be wiped)
- **Repository**: Private NixOS flake repository (optional for Deploy VM)
- **Token**: GitHub Personal Access Token for private repo access

## 🔧 Use Cases

This system can deploy **any NixOS configuration**:

- **🖥️ Server Infrastructure**: Web servers, databases, monitoring
- **🐳 Container Platforms**: Docker Swarm, Kubernetes, standalone containers
- **💻 Development**: Workstations, CI/CD runners, build systems
- **🌐 IoT & Edge**: Raspberry Pi clusters, edge computing nodes
- **🏢 Enterprise**: Managed workstations, centralized configuration
- **🎯 Custom Solutions**: Any NixOS system you can define








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
