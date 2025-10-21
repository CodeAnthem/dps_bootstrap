# Bootstrap System Documentation

**Interactive NixOS deployment scripts with shared libraries.**

## 🏗️ Architecture

```
bootstrap/
├── main.sh                      # Action discovery and entry point
├── lib/                         # Shared libraries
│   ├── setupConfiguration.sh    # Configuration engine
│   ├── setupConfiguration/      # Config modules (network, disk, custom)
│   ├── inputValidation/         # Validators (IP, hostname, disk, etc.)
│   ├── nixosSetup/              # NixOS operations (network, disk, install)
│   ├── formatting.sh            # Logging and UI functions
│   ├── userInput.sh             # Interactive prompts
│   ├── inputHelpers.sh          # Validation helpers
│   └── crypto.sh                # Encryption/SSH/Age keys
└── ../actions/                  # Deployment actions
    ├── deployVM/setup.sh        # Deploy VM action
    └── nixosNode/setup.sh       # Managed node action
```

**Actions-Based System:**
- Actions discovered automatically from `actions/` folder
- Each action has metadata and `setup()` function
- Shared libraries available to all actions
- Easy to extend with new deployment types

## 🔧 Core Components

### main.sh
**Purpose**: Action discovery and execution

**Features**:
- Recursively loads all libraries from `lib/`
- Discovers actions from `actions/` folder via metadata
- Root privilege validation with sudo fallback
- Interactive action selection menu
- Runtime directory setup with cleanup

### Configuration System
**Purpose**: Unified configuration management for all actions

**Features**:
- Module-based configuration (network, disk, custom)
- Environment variable overrides (`DPS_*`)
- Interactive configuration with validation
- Smart defaults per deployment type
- Validation-first workflow (forces fixes before proceeding)

### Available Actions

**deployVM** - Deploy VM with management tools
- Defaults: Encryption=yes, DHCP networking
- Installs deployment tools
- Uses `deployVM/nixosConfiguration/`

**nixosNode** - Managed NixOS node
- Role-based configuration from flake
- Static networking required
- Links to private config repository

## 📚 Library System

### Logging & UI (formatting.sh)
**Functions**:
- `log()`, `error()`, `success()`, `warn()` - Logging with timestamps
- `validation_error()` - Non-fatal validation errors
- `section_header()`, `draw_title()` - UI formatting
- `debug()` - Debug logging (enabled with DEBUG=1)

### Configuration System (setupConfiguration.sh)
**Core Functions**:
- `config_set()`, `config_get()` - Get/set config values
- `config_init()` - Initialize module with defaults
- `config_workflow()` - Complete config workflow (validate → display → interactive → confirm)
- `config_register_vars()` - Register custom variables dynamically
- `config_apply_env_overrides()` - Apply `DPS_*` environment variables

**Module Functions** (setupConfiguration/*.sh):
- `network` module - Hostname, IP, DNS, gateway configuration
- `disk` module - Disk target, encryption, partitioning
- `custom` module - Admin user, SSH port, timezone

### Validation (inputValidation/*.sh)
**Network Validators**:
- `validate_ip()`, `validate_hostname()`, `validate_netmask()`
- `validate_subnet()`, `validate_dns()`

**Disk Validators**:
- `validate_disk_path()`, `validate_disk_size()`
- `validate_partition_scheme()`

**Common Validators**:
- `validate_yes_no()`, `validate_username()`, `validate_port()`
- `validate_timezone()`, `validate_choice()`

### User Input (userInput.sh, inputHelpers.sh)
**Basic Prompts**:
- `prompt_yes_no()`, `prompt_password()`, `prompt_github_token()`

**Validated Prompts** (inputHelpers.sh):
- `prompt_validated()` - Generic validated input
- `prompt_bool()` - Boolean Y/N with normalization
- `prompt_choice()` - Choice from options
- `prompt_number()` - Numeric with range validation

### NixOS Operations (nixosSetup/*.sh)
**Network Configuration**:
- `generate_network_config()` - Create NixOS network config
- `configure_dhcp()`, `configure_static()` - Network modes

**Disk Operations**:
- `partition_disk()` - GPT partitioning with EFI
- `setup_encryption()` - LUKS encryption setup
- `mount_filesystems()` - Filesystem mounting

**Installation**:
- `generate_hardware_config()` - Hardware detection
- `install_nixos()` - NixOS installation
- `clone_repository()` - Git operations with auth

### Cryptography (crypto.sh)
**Functions**:
- `generate_encryption_key()` - LUKS key generation
- `generate_ssh_keypair()` - SSH key creation
- `generate_age_keypair()` - Age encryption keys

## ⚙️ Configuration

### Environment Variables

**Any configuration key can be set via `DPS_*` environment variables!**

Common variables:
- `DPS_HOSTNAME` - System hostname
- `DPS_DISK_TARGET` - Target disk (e.g., `/dev/sda`)
- `DPS_ENCRYPTION` - Enable encryption (`y`/`n`)
- `DPS_NETWORK_METHOD` - Network mode (`dhcp`/`static`)
- `DPS_IP_ADDRESS`, `DPS_NETWORK_MASK`, `DPS_NETWORK_GATEWAY` - Static IP config
- `DPS_ADMIN_USER` - Admin username
- `DPS_SSH_PORT` - SSH port number
- `DEBUG` - Enable debug logging (`1`/`0`)

**Example:**
```bash
export DPS_HOSTNAME="myserver"
export DPS_ADMIN_USER="admin"
export DPS_ENCRYPTION="y"
export DPS_NETWORK_METHOD="dhcp"
./main.sh
```

### Smart Defaults
**Deploy VM**: `DPS_ENCRYPTION="y"`, `DPS_NETWORK_METHOD="dhcp"`
**Managed Node**: `DPS_ENCRYPTION="n"`, static IP required

### Configuration Workflow
1. **Validation** - All settings validated before confirmation
2. **Display** - Current configuration shown with defaults
3. **Interactive Mode** - Triggered automatically if validation fails or on request
4. **Confirmation** - User confirms before proceeding

If required fields are empty or invalid, interactive mode is **forced** to fix errors.

## 🔍 Debugging

**Enable Debug Mode**:
```bash
export DEBUG=1
./main.sh
```

**Debug Output Shows**:
- Library loading (recursive)
- Module registration
- Environment variable overrides
- Configuration key registration
- Validation steps and errors

**Common Issues**:
- **"Hostname is required"** - Interactive mode will prompt for it
- **"Module not registered"** - Action's setup.sh has issues
- **"Invalid disk target"** - Check `lsblk` for available disks
- **Library loading** - Check file permissions, avoid `_` prefix (ignored files)
- **Root privileges** - Script will prompt for sudo if needed

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

## 📖 Additional Documentation

- **Developer Guide** - [README_dev.md](README_dev.md) - Extending and modifying the system
- **Main Project** - [../README.md](../README.md) - Project overview
- **Architecture** - [../PLAN.md](../PLAN.md) - Technical architecture details

---

**Version**: 4.0 (Actions-based with configuration system)  
**Last Updated**: 2025-10-21
