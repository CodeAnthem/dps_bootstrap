# Bootstrap System

**Interactive NixOS deployment with modular configuration system.**

## Overview

The bootstrap system provides an action-based deployment framework with:
- **Configuration System** - Module-based config with validation
- **Input Handlers** - Type-safe input validation and transformation
- **Action System** - Auto-discovered deployment actions
- **Workflows** - Interactive and automated deployment modes

## Architecture

```
bootstrap/
├── main.sh                          # Entry point & action discovery
├── start.sh                         # One-liner download script
├── lib/                             # Shared libraries
│   ├── 1_inputs/                    # Input handlers
│   │   ├── network/                 # IP, hostname, mask, port
│   │   ├── system/                  # Timezone, username, path, url
│   │   ├── disk/                    # Disk selection, size
│   │   ├── primitive/               # String, int, float, toggle, choice
│   │   ├── API.md                   # Input API reference
│   │   └── README.md                # Input documentation
│   ├── 2_configuration/             # Configuration system
│   │   ├── core.sh                  # Data storage & registries
│   │   ├── field.sh                 # Field validation & prompting
│   │   ├── module.sh                # Module operations
│   │   ├── workflow.sh              # User workflows
│   │   ├── modules/                 # Configuration modules
│   │   │   ├── network.sh           # Network configuration
│   │   │   ├── disk.sh              # Disk configuration
│   │   │   └── system.sh            # System configuration
│   │   ├── API.md                   # Module API reference
│   │   └── README.md                # Configuration documentation
│   ├── nixosSetup/                  # NixOS operations
│   │   ├── network.sh               # Network config generation
│   │   ├── disk.sh                  # Partitioning & encryption
│   │   └── installation.sh          # NixOS installation
│   ├── formatting.sh                # Logging & UI
│   ├── userInput.sh                 # Legacy prompts
│   └── crypto.sh                    # Encryption & SSH keys
└── ../actions/                      # Deployment actions
    ├── deployVM/                    # Deploy VM action
    ├── nixosNode/                   # Managed node action
    └── test/                        # Test suite
```

## 🔧 Core Components

### main.sh
**Purpose**: Action discovery and execution

**Features**:
- Recursively loads all libraries from `lib/`
- Discovers actions from `actions/` folder via metadata
- Root privilege validation with sudo fallback
- Interactive action selection menu
- Runtime directory setup with cleanup

### Configuration System (`lib/2_configuration/`)
**Purpose**: Module-based configuration with validation

**Key Features**:
- Conditional fields (e.g., IP only shown for static networking)
- Cross-field validation (e.g., gateway must differ from IP)
- Environment variable overrides (`DPS_*`)
- Interactive menu with validation loop
- See [lib/2_configuration/README.md](lib/2_configuration/README.md) for details

**Available Modules**:
- `network` - Hostname, IP, DNS, gateway
- `disk` - Disk target, encryption, partitioning
- `system` - Admin user, SSH port, timezone

### Input Handlers (`lib/1_inputs/`)
**Purpose**: Validate and transform user input

**16 Input Types**:
- Network: `ip`, `hostname`, `mask`, `port`
- System: `timezone`, `username`, `path`, `url`
- Disk: `disk`, `disk_size`
- Primitive: `choice`, `string`, `int`, `float`, `toggle`, `question`

**Each input handler provides**:
- `validate_*()` - Validate input
- `error_msg_*()` - Error messages
- `normalize_*()` - Transform for storage
- `display_*()` - Transform for display
- See [lib/1_inputs/README.md](lib/1_inputs/README.md) for details

### Available Actions

**deployVM** - Deploy VM with management tools
- Configuration: network + disk + system + deploy
- Features: Auto encryption, DHCP default

**nixosNode** - Managed NixOS node  
- Configuration: network (static) + system
- Features: Role-based config from flake

**test** - Test suite
- Runs input handler tests
- Validates configuration system

## Core Libraries

### Logging & UI (`formatting.sh`)
- `log()`, `error()`, `success()`, `warn()` - Timestamped logging
- `validation_error()` - Non-fatal validation errors
- `section_header()` - UI section headers
- `debug()` - Debug logging (DEBUG=1)

### NixOS Operations (`nixosSetup/`)
- `network.sh` - Generate network configuration
- `disk.sh` - Partition, encrypt, mount
- `installation.sh` - Install NixOS, hardware config

### Cryptography (`crypto.sh`)
- `generate_encryption_key()` - LUKS keys
- `generate_ssh_keypair()` - SSH keys
- `generate_age_keypair()` - Age encryption

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

### Configuration Workflow

Actions use: `config_workflow("network", "disk", "system")`

**Automatic workflow:**
1. **Fix Errors** - Prompt only for missing/invalid required fields
2. **Interactive Menu** - Show all modules, user can edit any
3. **Validation Loop** - Can't exit module until validation passes
4. **Confirm** - User presses X to proceed (validates all modules)

**Features:**
- Smart defaults per action (deployVM: encryption=true, dhcp)
- Conditional fields (IP only for static networking)
- Cross-field validation (gateway ≠ IP, same subnet)
- Environment overrides applied automatically

## Quick Start

**One-liner (downloads and runs):**
```bash
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/start.sh | bash
```

**With environment variables:**
```bash
export DPS_HOSTNAME="myserver"
export DPS_NETWORK_METHOD="dhcp"
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/start.sh | bash
```

**Local execution:**
```bash
./bootstrap/main.sh
```

## Debugging

**Enable debug mode:**
```bash
export DEBUG=1
./main.sh
```

## Documentation

- **[lib/1_inputs/README.md](lib/1_inputs/README.md)** - Input handlers
- **[lib/1_inputs/API.md](lib/1_inputs/API.md)** - Input API reference
- **[lib/2_configuration/README.md](lib/2_configuration/README.md)** - Configuration system
- **[lib/2_configuration/API.md](lib/2_configuration/API.md)** - Module API reference
- **[../README.md](../README.md)** - Project overview
- **[../PLAN.md](../PLAN.md)** - Architecture details

## Development

See [README_dev.md](README_dev.md) for:
- Creating new input handlers
- Creating new configuration modules
- Creating new actions
- Testing and validation
