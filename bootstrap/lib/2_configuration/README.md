# Configuration System

## Overview

The configuration system provides module-based configuration management with field validation, conditional fields, cross-field validation, and interactive workflows.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ ACTION LAYER (actions/*/setup.sh)                        │
│   config_use_module(), config_workflow(), config_get()  │
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ WORKFLOW LAYER (workflow.sh)                             │
│   config_fix_errors(), config_menu(), config_workflow()  │
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ MODULE LAYER (module.sh)                                 │
│   module_validate(), module_prompt_all(), module_display()│
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ FIELD LAYER (field.sh)                                   │
│   field_validate(), field_prompt(), generic_input_loop() │
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ CORE LAYER (core.sh)                                     │
│   CONFIG_DATA, FIELD_REGISTRY, config_get(), config_set()│
└──────────────────────────────────────────────────────────┘
```

---

## Core Components

### core.sh - Data Layer
**Purpose:** Data storage and registries  
**Provides:**
- `CONFIG_DATA` - Stores configuration values
- `FIELD_REGISTRY` - Stores field metadata
- `config_get/set` - Data access functions
- `field_declare` - Register field metadata

### field.sh - Field Operations
**Purpose:** Single field validation and prompting  
**Provides:**
- `field_validate` - Validate one field
- `field_prompt` - Prompt for one field
- `generic_input_loop` - Standard prompt logic

### module.sh - Module Operations  
**Purpose:** Module-level validation and display  
**Provides:**
- `module_validate` - Validate all fields
- `module_prompt_all` - Prompt all fields
- `module_display` - Show configuration

### workflow.sh - User Workflows
**Purpose:** High-level user interactions  
**Provides:**
- `config_fix_errors` - Fix validation errors
- `config_menu` - Interactive category menu
- `config_workflow` - Complete workflow

---

## Quick Start

### Using the Configuration System

**In an action (setup.sh):**
```bash
# 1. Load modules
config_use_module "network"
config_use_module "disk"
config_use_module "system"

# 2. Run interactive workflow
config_workflow "network" "disk" "system"

# 3. Access configuration
hostname=$(config_get "network" "HOSTNAME")
disk=$(config_get "disk" "DISK_TARGET")
admin_user=$(config_get "system" "ADMIN_USER")

echo "Hostname: $hostname"
echo "Disk: $disk"
echo "Admin: $admin_user"
```

**That's it!** The system handles:
- ✅ Field prompting
- ✅ Input validation
- ✅ Error messages
- ✅ Interactive menu
- ✅ Cross-field validation

---

## Available Modules

### Network Module (`network`)
**Fields:**
- Hostname
- Network Method (dhcp/static)
- DNS Servers
- IP Address (static only)
- Network Mask (static only)
- Gateway (static only)

**Cross-field validation:**
- Gateway must differ from IP
- Gateway must be in same subnet as IP

### Disk Module (`disk`)
**Fields:**
- Target Disk
- Enable Encryption
- Encryption Settings (if enabled)
- Partition Scheme

### System Module (`system`)
**Fields:**
- Admin Username
- SSH Port
- Timezone

---

## API Reference

For complete API documentation, see **[API.md](./API.md)**

### Module API

**Required functions:**
- `{module}_init_callback()` - Declare fields
- `{module}_get_active_fields()` - List active fields

**Optional functions:**
- `{module}_validate_extra()` - Cross-field validation

### Public API (Actions)

**Module management:**
```bash
config_use_module "module"      # Load standard module
config_init_module "module"     # Initialize inline module
```

**Workflows:**
```bash
config_workflow "mod1" "mod2"   # Complete workflow
config_fix_errors "mod1" "mod2" # Fix errors only
config_menu "mod1" "mod2"       # Interactive menu
```

**Data access:**
```bash
config_get "module" "FIELD"     # Get value
hostname=$(config_get "network" "HOSTNAME")
```

---

## Creating Configuration Modules

See **[API.md](./API.md)** for step-by-step guide.

**Quick example:**
```bash
# 1. Create file: modules/deploy.sh

deploy_init_callback() {
    field_declare GIT_REPO_URL \
        display="Git Repository" \
        input=url \
        required=true
    
    field_declare DEPLOY_KEY_PATH \
        display="Deploy SSH Key" \
        input=path \
        default="/root/.ssh/deploy_key"
}

deploy_get_active_fields() {
    echo "GIT_REPO_URL"
    echo "DEPLOY_KEY_PATH"
}

# 2. Use in action:
config_use_module "deploy"
config_workflow "network" "disk" "deploy"
```

---

## Conditional Fields

Fields can appear/disappear based on other field values:

```bash
network_get_active_fields() {
    local method
    method=$(config_get "network" "NETWORK_METHOD")
    
    echo "HOSTNAME"
    echo "NETWORK_METHOD"
    
    # Static-only fields
    if [[ "$method" == "static" ]]; then
        echo "NETWORK_IP"
        echo "NETWORK_GATEWAY"
    fi
}
```

**Result:**
```
Method: dhcp   → Shows: HOSTNAME, NETWORK_METHOD
Method: static → Shows: HOSTNAME, NETWORK_METHOD, IP, GATEWAY
```

---

## Cross-Field Validation

Validate relationships between fields:

```bash
network_validate_extra() {
    local ip
    local gateway
    ip=$(config_get "network" "NETWORK_IP")
    gateway=$(config_get "network" "NETWORK_GATEWAY")
    
    if [[ "$ip" == "$gateway" ]]; then
        validation_error "Gateway cannot be same as IP"
        return 1
    fi
    
    return 0
}
```

**User sees:**
```
❌ [VALIDATION] - Gateway cannot be same as IP
⚠️  [WARN] - Configuration has validation errors - please review and fix:

╭────────────────────────────────────────────────╮
│  Network Configuration                         │
╰────────────────────────────────────────────────╯

  IP Address           [192.168.1.1]: 
  Gateway              [192.168.1.1]: 192.168.1.254
```

---

## Environment Variable Overrides

All modules automatically support environment overrides:

```bash
export DPS_HOSTNAME="myserver"
export DPS_NETWORK_METHOD="static"
export DPS_NETWORK_IP="192.168.1.10"

config_use_module "network"
# Values automatically applied
```

**Pattern:** `DPS_{FIELD_NAME}=value`

---

## Workflows

### 1. Fix Errors Only (Minimal)
```bash
config_fix_errors "network" "disk"
```
- Prompts only for missing required fields
- No menu, no full prompts
- Fast for automated deployments

### 2. Interactive Menu (Full)
```bash
config_menu "network" "disk"
```
- Shows all modules
- User can edit any field
- Validates before proceeding
- Loops until valid

### 3. Complete Workflow (Recommended)
```bash
config_workflow "network" "disk"
```
- Fix errors first
- Then show interactive menu
- Best user experience

---

## Data Flow Example

```
1. Action calls: config_workflow("network")

2. Workflow fixes errors:
   module_prompt_errors("network")
     → Prompt only for missing/invalid fields

3. Workflow shows menu:
   module_display("network")
     → Show current configuration

4. User selects "Edit Network":
   module_prompt_all("network")
     → Prompt all active fields
   
   For each field:
     field_prompt("network", "HOSTNAME")
       → generic_input_loop()
          → validate_hostname()
          → normalize_hostname() (if exists)
          → Store in CONFIG_DATA

5. Validate after editing:
   module_validate("network")
     → field_validate() for each field
     → network_validate_extra() for cross-field

6. If invalid, loop back to step 4
   If valid, return to menu

7. User presses X:
   → Validate all modules
   → If valid, proceed
   → If invalid, warn and loop

8. Action retrieves values:
   hostname=$(config_get "network" "HOSTNAME")
```

---

## Best Practices

1. **One module = one concern** - Network, Disk, System
2. **Use conditional fields** - Don't show irrelevant fields
3. **Validate relationships** - Use `validate_extra()` for cross-field checks
4. **Set sensible defaults** - Users can press Enter to accept
5. **Group logically** - Related fields together
6. **Document purpose** - Clear field display names

---

## Advanced Features

### Inline Modules
Actions can create modules without separate files:

```bash
# Define callbacks
deploy_init_callback() {
    field_declare GIT_REPO \
        display="Repository" \
        input=url \
        required=true
}

deploy_get_active_fields() {
    echo "GIT_REPO"
}

# Initialize inline
config_init_module "deploy"
deploy_init_callback

# Use in workflow
config_workflow "network" "deploy"
```

### Field Metadata
Fields can have custom options passed to input handlers:

```bash
field_declare SSH_PORT \
    display="SSH Port" \
    input=port \
    required=true \
    min=1024 \        # Custom option
    max=49151         # Custom option
```

### Dynamic Defaults
Compute defaults in init callback:

```bash
disk_init_callback() {
    # Auto-detect first disk
    local default_disk
    default_disk=$(list_available_disks | head -n1 | awk '{print $1}')
    
    field_declare DISK_TARGET \
        display="Target Disk" \
        input=disk \
        default="$default_disk"
}
```

---

## Directory Structure

```
2_configuration/
├── core.sh                    # Data layer
├── field.sh                   # Field operations
├── module.sh                  # Module operations
├── workflow.sh                # User workflows
├── modules/                   # Standard modules
│   ├── network.sh
│   ├── disk.sh
│   └── system.sh
├── API.md                     # API reference
└── README.md                  # This file
```

---

## See Also

- **[API.md](./API.md)** - Complete API reference
- **[../1_inputs/README.md](../1_inputs/README.md)** - Input handlers
- **[../../README.md](../../README.md)** - Bootstrap system overview
