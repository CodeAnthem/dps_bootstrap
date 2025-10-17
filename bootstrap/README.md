# Bootstrap System Documentation

**Interactive NixOS deployment scripts with shared libraries.**

## 🏗️ Architecture

```
bootstrap/
├── main.sh                     # Mode selector and entry point
├── setup_deploy_vm.sh          # Deploy VM workflow
├── setup_managed_node.sh       # Managed Node workflow
└── lib/                        # Shared libraries
    ├── common.sh               # Logging, UI, utilities
    ├── validation.sh           # Input validation
    ├── disk-setup.sh           # Partitioning, encryption
    ├── network-setup.sh        # Network configuration
    └── nix-setup.sh            # NixOS installation
```

## 🔧 Core Scripts

### main.sh
**Purpose**: Mode selection and system initialization

**Features**:
- Loads all libraries from `lib/`
- Root privilege validation with sudo fallback
- Interactive Deploy VM vs Managed Node selection
- Runtime directory setup with cleanup

### setup_deploy_vm.sh
**Purpose**: Deploy VM installation workflow

**Process**:
1. Load Deploy VM defaults (encryption=yes, DHCP)
2. Disk setup with encryption
3. Install NixOS with `deployVM/configuration.nix`
4. Install deployment tools

### setup_managed_node.sh
**Purpose**: Managed Node installation workflow

**Process**:
1. Collect role, hostname, IP (interactive prompts)
2. Clone private repository (read-only)
3. Install NixOS with flake + hardware override
4. Create `dps-update` script

## 📚 Library System

### lib/common.sh
**Functions**:
- `log()`, `error()`, `success()` - Logging with timestamps
- `section_header()`, `step_start()` - UI formatting
- `prompt_github_token()` - Secure token input
- `nix_shell_wrapper()` - Nix command execution

### lib/validation.sh
**Functions**:
- `validate_ip_address()`, `validate_hostname()`
- `validate_deploy_config()`, `validate_node_config()`

### lib/disk-setup.sh
**Functions**:
- `partition_disk()` - GPT partitioning with EFI
- `setup_encryption()` - LUKS encryption setup
- `mount_filesystems()` - Filesystem mounting

### lib/network-setup.sh
**Functions**:
- `configure_dhcp_network()`, `configure_static_network()`
- `test_network_connectivity()`

### lib/nix-setup.sh
**Functions**:
- `generate_hardware_config()` - Hardware detection
- `install_deploy_vm()`, `install_managed_node()` - NixOS installation
- `clone_repository()` - Git operations with auth

## ⚙️ Configuration

### Environment Variables
- `DPS_HOSTNAME`, `DPS_DISK_TARGET`, `DPS_ENCRYPTION`
- `DPS_NETWORK_METHOD`, `DPS_IP_ADDRESS`
- `DPS_ROLE` (for managed nodes)
- `DPS_DEBUG` - Enable verbose logging

### Smart Defaults
**Deploy VM**: `DPS_ENCRYPTION="y"`, `DPS_NETWORK_METHOD="dhcp"`
**Managed Node**: `DPS_ENCRYPTION="n"`, static IP required

## 🔍 Debugging

**Enable Debug Mode**:
```bash
export DPS_DEBUG=1
./main.sh
```

**Common Issues**:
- Library loading: Check file permissions in `lib/`
- Root privileges: Verify sudo access
- Network: Validate IP format and availability

## 📋 Usage

**Basic Usage**:
```bash
./main.sh  # Interactive mode selection
```

**Pre-configured**:
```bash
export DPS_HOSTNAME="deploy-01"
export DPS_DISK_TARGET="/dev/nvme0n1"
./main.sh
```

---

For installation guides, see [README_deployVM.md](README_deployVM.md) and [README_deployNode.md](README_deployNode.md).
