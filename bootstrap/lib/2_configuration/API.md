# Configuration Module API Reference

## Overview

Configuration modules organize related fields (e.g., `network`, `disk`, `system`) and implement field initialization, conditional field logic, and cross-field validation.

---

## Module API Functions

### Required Functions

#### `{module}_init_callback()`

**Purpose:** Initialize module fields  
**Context:** `MODULE_CONTEXT` is set to module name  
**Returns:** Nothing  
**When called:** During `config_use_module()` or `config_init_module()`

**Example:**
```bash
network_init_callback() {
    # MODULE_CONTEXT is already set to "network"
    
    field_declare HOSTNAME \
        display="Hostname" \
        input=hostname \
        required=true
    
    field_declare NETWORK_METHOD \
        display="Network Method" \
        input=choice \
        default="dhcp" \
        required=true \
        options="dhcp|static"
    
    field_declare NETWORK_IP \
        display="IP Address" \
        input=ip \
        required=true
}
```

**Field Declaration Parameters:**
- `display` - Human-readable field name (required)
- `input` - Input handler type (required)
- `required` - true/false (optional, default: false)
- `default` - Default value (optional)
- Custom options passed to input handler (e.g., `min`, `max`, `options`)

---

#### `{module}_get_active_fields()`

**Purpose:** Return list of currently active fields  
**Context:** `MODULE_CONTEXT` is set to module name  
**Returns:** Field names, one per line via stdout  
**When called:** During validation, prompting, and display

**Example:**
```bash
network_get_active_fields() {
    local method
    method=$(config_get "network" "NETWORK_METHOD")
    
    # Base fields always active
    echo "HOSTNAME"
    echo "NETWORK_METHOD"
    echo "NETWORK_DNS_PRIMARY"
    echo "NETWORK_DNS_SECONDARY"
    
    # Conditional fields for static configuration
    if [[ "$method" == "static" ]]; then
        echo "NETWORK_IP"
        echo "NETWORK_MASK"
        echo "NETWORK_GATEWAY"
    fi
}
```

**Conditional Field Behavior:**
```
Method: dhcp  → Shows: HOSTNAME, NETWORK_METHOD, DNS fields
Method: static → Shows: All above + IP, MASK, GATEWAY
```

---

### Optional Functions

#### `{module}_validate_extra()`

**Purpose:** Cross-field validation (relationships between fields)  
**Context:** `MODULE_CONTEXT` is set to module name  
**Returns:**
- `0` - validation passed
- `non-zero` - validation failed

**Side Effects:** Call `validation_error()` for each error

**When to implement:** Validate field relationships (e.g., IP must be different from Gateway)

**Example:**
```bash
network_validate_extra() {
    local method
    method=$(config_get "network" "NETWORK_METHOD")
    
    if [[ "$method" == "static" ]]; then
        local ip
        local gateway
        ip=$(config_get "network" "NETWORK_IP")
        gateway=$(config_get "network" "NETWORK_GATEWAY")
        
        # Check if Gateway is same as IP
        if [[ -n "$ip" && -n "$gateway" && "$ip" == "$gateway" ]]; then
            validation_error "Gateway cannot be the same as IP address"
            return 1
        fi
        
        # Check subnet relationship
        local mask
        mask=$(config_get "network" "NETWORK_MASK")
        if [[ -n "$ip" && -n "$mask" && -n "$gateway" ]]; then
            if ! validate_subnet "$ip" "$mask" "$gateway"; then
                validation_error "Gateway must be in the same subnet as IP"
                return 1
            fi
        fi
    fi
    
    return 0
}
```

---

## Module Lifecycle

```
1. Load Module
   config_use_module "network"
   ├─→ Source network.sh
   ├─→ Set MODULE_CONTEXT="network"
   ├─→ Call network_init_callback()
   │   └─→ field_declare for each field
   └─→ config_apply_env_overrides("network")
       └─→ Apply DPS_* environment variables

2. Run Workflow
   config_workflow "network" "disk"
   ├─→ config_fix_errors()
   │   └─→ module_prompt_errors() for each module
   │       └─→ Prompt only fields that failed validation
   │
   └─→ config_menu()
       ├─→ nds_module_display() for each module
       │   └─→ Show current configuration
       │
       └─→ User selects module to edit
           └─→ module_prompt_all()
               └─→ Prompt all active fields

3. Validation
   module_validate("network")
   ├─→ For each field in network_get_active_fields():
   │   └─→ field_validate()
   │       ├─→ validate_{input}()
   │       └─→ error_msg_{input}() if failed
   │
   └─→ network_validate_extra() (if exists)
       └─→ Cross-field validation

4. Display
   nds_module_display("network")
   └─→ For each field in network_get_active_fields():
       ├─→ config_get() - Get stored value
       ├─→ display_{input}() - Transform for display (if exists)
       └─→ console output
```

---

## Configuration Data Access

### Public API (Used by Actions)

```bash
# Load and initialize standard module
config_use_module "network"

# Initialize custom inline module
config_init_module "deploy"
deploy_init_callback() {
    field_declare GIT_REPO_URL \
        display="Git Repository" \
        input=url \
        required=true
}

# Set action-specific defaults (optional)
# These override module defaults but respect DPS_* env vars
config_set_default "disk" "ENCRYPTION" "true"
config_set_default "network" "NETWORK_METHOD" "dhcp"

# Run interactive workflow
config_workflow "network" "disk" "deploy"

# Access configuration
hostname=$(config_get "network" "HOSTNAME")
disk=$(config_get "disk" "DISK_TARGET")
```

---

### Internal API (Used by Modules)

```bash
# Get configuration value
config_get "module" "FIELD_NAME"

# Set configuration value (rarely needed - prompts do this)
config_set "module" "FIELD_NAME" "value"

# Set action-specific default (respects environment variables)
# Priority: module default < action default < environment variable
# Use this in action setup.sh to override module defaults
config_set_default "module" "FIELD_NAME" "value"

# Get field metadata
field_get "module" "FIELD_NAME" "display"
field_get "module" "FIELD_NAME" "required"
field_get "module" "FIELD_NAME" "input"

# Check field existence
field_exists "module" "FIELD_NAME"
```

---

## Creating New Modules

### Step 1: Create File

Create `bootstrap/lib/2_configuration/modules/{module}.sh`

### Step 2: Add Header

```bash
#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-XX-XX | Modified: 2025-XX-XX
# Description:   Script Library File
# Feature:       {Module} configuration module
# ==================================================================================================
```

### Step 3: Implement Init Callback

```bash
{module}_init_callback() {
    # Declare all fields
    field_declare FIELD_NAME \
        display="Display Name" \
        input=input_type \
        required=true \
        default="default_value"
}
```

### Step 4: Implement Get Active Fields

```bash
{module}_get_active_fields() {
    # Return all field names, one per line
    echo "FIELD_NAME_1"
    echo "FIELD_NAME_2"
    
    # Conditional fields
    if [[ "$(config_get "{module}" "SOME_FIELD")" == "value" ]]; then
        echo "CONDITIONAL_FIELD"
    fi
}
```

### Step 5: Implement Extra Validation (Optional)

```bash
{module}_validate_extra() {
    # Cross-field validation
    local field1
    local field2
    field1=$(config_get "{module}" "FIELD1")
    field2=$(config_get "{module}" "FIELD2")
    
    if [[ "$field1" == "$field2" ]]; then
        validation_error "Field1 cannot equal Field2"
        return 1
    fi
    
    return 0
}
```

### Step 6: Use in Action

```bash
# In actions/*/setup.sh
config_use_module "{module}"
config_workflow "{module}"
```

**Done!** The system handles validation, prompting, and display automatically.

---

## Workflow Functions

### High-Level Workflows

```bash
# Fix validation errors only (minimal prompting)
config_fix_errors "network" "disk" "system"

# Interactive category menu (edit any field)
config_menu "network" "disk" "system"

# Complete workflow: fix errors → menu → validate
config_workflow "network" "disk" "system"
```

---

### Module Operations

```bash
# Validate all active fields + extra validation
module_validate "network"

# Prompt only fields that failed validation
module_prompt_errors "network"

# Prompt all active fields (interactive edit)
module_prompt_all "network"

# Display module configuration
nds_module_display "network"
nds_module_display "network" "1"  # With number prefix
```

---

### Field Operations

```bash
# Validate single field
field_validate "network" "HOSTNAME"

# Prompt for single field
field_prompt "network" "HOSTNAME"
```

---

## Environment Variable Overrides

Modules automatically support environment variable overrides:

```bash
export DPS_HOSTNAME="myhost"
export DPS_NETWORK_METHOD="static"
export DPS_NETWORK_IP="192.168.1.10"

config_use_module "network"
# Values are automatically applied
```

**Pattern:** `DPS_{FIELD_NAME}=value`

**Applied during:** `config_use_module()` and `config_init_module()`

---

## Inline Modules (Action-Specific)

Actions can create custom modules inline without creating separate files:

```bash
# In actions/deployVM/setup.sh
deploy_init_callback() {
    field_declare GIT_REPO_URL \
        display="Git Repository" \
        input=url \
        required=true
}

deploy_get_active_fields() {
    echo "GIT_REPO_URL"
    echo "DEPLOY_SSH_KEY_PATH"
}

# Initialize inline module
config_init_module "deploy"
deploy_init_callback

# Use in workflow
config_workflow "network" "disk" "deploy"
```

---

## Best Practices

1. **One module = one concern** - Network, Disk, System, etc.
2. **Use conditional fields** - Don't show irrelevant fields
3. **Validate relationships** - Use `{module}_validate_extra()` for cross-field checks
4. **Set sensible defaults** - Users can press Enter to accept
5. **Group related fields** - Logical organization helps users
6. **Document field purpose** - Clear `display` names
7. **Return field list dynamically** - `get_active_fields()` can change based on state

---

## Architecture Layers

```
┌──────────────────────────────────────────────────────────┐
│ ACTION LAYER (setup.sh)                                   │
│   config_use_module(), config_workflow(), config_get()   │
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ WORKFLOW LAYER (workflow.sh)                             │
│   config_fix_errors(), config_menu(), config_workflow()  │
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ MODULE LAYER (module.sh)                                 │
│   module_validate(), module_prompt_all(), nds_module_display()│
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ FIELD LAYER (field.sh)                                   │
│   field_validate(), field_prompt(), generic_input_loop() │
└─────────────────┬────────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│ INPUT LAYER (inputs/*.sh)                                │
│   validate_*(), normalize_*(), display_*(), prompt_*()   │
└──────────────────────────────────────────────────────────┘
```

**Clean separation:** Each layer has a clear responsibility.
