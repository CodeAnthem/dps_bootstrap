# DPS Bootstrap - NixOS Deployment System

**WARNING** ⚠️  - __This system is in active development and is not yet ready for production use.__

**WARNING** ⚠️  - __This system is in active development and is not yet ready for production use.__

**WARNING** ⚠️  - __This system is in active development and is not yet ready for production use.__


**Automated NixOS deployment system** - Transform any NixOS Live ISO into a Deploy VM management hub or managed infrastructure node with a single command.

## 🚀 Quick Start


Download and boot from **Minimal NixOS ISO**
https://nixos.org/download/

### One-liner Installation (Recommended)

```bash
# Boot from NixOS ISO, set root password, then run:
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/start.sh | bash
```

The script will:
1. **Download** the latest repository to `/tmp/dps_bootstrap/`
2. **Verify** repository integrity and handle untracked files
3. **Launch** the interactive bootstrap selector
4. **Guide** you through Deploy VM or Managed Node setup

### Alternative: Manual Installation

```bash
# 1. Download and verify
curl -fsSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/start.sh -o /tmp/bootstrap_temp.sh
chmod +x /tmp/bootstrap_temp.sh
bash -n /tmp/bootstrap_temp.sh

# 2. Execute if verification passes
/tmp/bootstrap_temp.sh
```

## 🏗️ What This System Does

**DPS Bootstrap** creates two types of NixOS systems:

### 🎯 Deploy VM (Management Hub)
- **Purpose**: Central management and deployment system
- **Access**: Write access to your private NixOS flake repository
- **Features**: SOPS key management, SSH orchestration, cluster deployment tools
- **Security**: Encrypted by default, stateless and recoverable

### 🔧 Managed Nodes (Infrastructure)
- **Purpose**: Any NixOS configuration from your private flake
- **Access**: Read-only access to your private repository
- **Types**: Servers, workstations, IoT devices, containers, custom systems
- **Updates**: Automated configuration pulls and system updates

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

## 📚 Documentation

- **[PLAN.md](PLAN.md)** - Detailed project architecture and background information
- **[bootstrap/README.md](bootstrap/README.md)** - Bootstrap script documentation
- **[bootstrap/README_deployVM.md](bootstrap/README_deployVM.md)** - Deploy VM setup guide
- **[bootstrap/README_deployNode.md](bootstrap/README_deployNode.md)** - Managed Node setup guide
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

All settings can be customized through environment variables or interactive prompts.

## 🛡️ Security Features

- **🔐 Secure Tokens**: Interactive GitHub token input (never stored)
- **🔑 Encryption**: LUKS full-disk encryption with multiple key methods
- **🚫 Access Control**: Deploy VM (write) vs Managed Nodes (read-only)
- **🧹 Cleanup**: Automatic credential and temporary file cleanup
- **🔍 Integrity**: Repository verification and untracked file detection

## 🆘 Support

- **Debug Mode**: Set `export DPS_DEBUG=1` for verbose logging
- **Common Issues**: Check disk paths, network configuration, and repository access
- **Repository Structure**: Ensure your private flake follows NixOS conventions

## 📄 License

This project is open source. See individual files for specific license information.

---

**Ready to deploy?** Run the one-liner above and let DPS Bootstrap handle the rest! 🚀
