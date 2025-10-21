# Bootstrap System - Developer Guide

**Extending and modifying the bootstrap system**

For user documentation, see [README.md](README.md).

---

## Creating a New Action

### 1. Create Action Structure

```bash
actions/
└── myAction/
    ├── setup.sh           # Required: main setup script
    ├── README.md          # Optional: action documentation
    └── resources/         # Optional: templates, configs
```

### 2. Write setup.sh

```bash
#!/usr/bin/env bash
# ==================================================================================================
# Metadata (required for discovery)
# Description: My Custom Deployment Action
# Version: 1.0
# ==================================================================================================

# Setup function (required)
setup() {
    local action_name="$1"
    
    # Option A: Use existing modules
    config_init "$action_name" "network"
    config_init "$action_name" "disk"
    
    # Option B: Register custom variables
    config_register_vars "$action_name" \
        "MY_VAR:default_value" \
        "API_KEY:"
    
    # Run interactive configuration workflow
    config_workflow "$action_name" "network" "disk"
    
    # Access configuration
    local hostname=$(config_get "$action_name" "network" "HOSTNAME")
    local my_var=$(config_get_var "$action_name" "MY_VAR")
    
    # Perform deployment...
    log "Deploying $hostname..."
}
```

**That's it!** The action will be discovered automatically by `main.sh`.

---

## Creating a Configuration Module

Full module with all callbacks (init, display, interactive, validate).

### Module Template

```bash
#!/usr/bin/env bash
# lib/setupConfiguration/mymodule.sh

# =============================================================================
# INIT CALLBACK
# =============================================================================
mymodule_init_callback() {
    local action="$1"
    local module="$2"
    shift 2
    
    # Define defaults
    local defaults=(
        "SETTING1:default1"
        "SETTING2:option1|option1|option2"
    )
    
    # Parse and store config
    for config_pair in "${defaults[@]}"; do
        local key="${config_pair%%:*}"
        local value="${config_pair#*:}"
        local default_value="${value%%|*}"
        
        config_set "$action" "$module" "$key" "$default_value"
    done
}

# =============================================================================
# DISPLAY CALLBACK
# =============================================================================
mymodule_display_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module Configuration:"
    console "  SETTING1: $(config_get "$action" "$module" "SETTING1")"
    console "  SETTING2: $(config_get "$action" "$module" "SETTING2")"
}

# =============================================================================
# INTERACTIVE CALLBACK
# =============================================================================
mymodule_interactive_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module Configuration:"
    console ""
    
    # Use input helpers
    local setting1=$(config_get "$action" "$module" "SETTING1")
    local new_setting1=$(prompt_validated "SETTING1" "$setting1" "validate_something" "required")
    update_if_changed "$action" "$module" "SETTING1" "$setting1" "$new_setting1"
    
    console ""
}

# =============================================================================
# VALIDATION CALLBACK
# =============================================================================
mymodule_validate_callback() {
    local action="$1"
    local module="$2"
    local validation_errors=0
    
    local setting1=$(config_get "$action" "$module" "SETTING1")
    if [[ -z "$setting1" ]]; then
        validation_error "SETTING1 is required"  # NOT error() - that exits!
        ((validation_errors++))
    fi
    
    return "$validation_errors"
}

# =============================================================================
# REGISTRATION
# =============================================================================
config_register_module "mymodule" \
    "mymodule_init_callback" \
    "mymodule_display_callback" \
    "mymodule_interactive_callback" \
    "mymodule_validate_callback"
```

### Using Input Helpers

Replace validation loops with helpers:

```bash
# Validated input with custom validator
new_value=$(prompt_validated "IP_ADDRESS" "$current" "validate_ip" "required" "Invalid IP")

# Boolean Y/N
enabled=$(prompt_bool "ENABLE" "$current")

# Choice from options
method=$(prompt_choice "METHOD" "$current" "dhcp|static")

# Number with range
port=$(prompt_number "PORT" "$current" 1 65535 "required")

# Update only if changed
update_if_changed "$action" "$module" "KEY" "$old" "$new"
```

---

## Code Style

### Function Naming
- **Public API:** `config_*`, `validate_*`, `prompt_*`
- **Module callbacks:** `modulename_*_callback`
- **Internal/ignored:** `_function_name` (underscore prefix)

### Error Handling
```bash
error "fatal error"                # Exits with code 2
validation_error "bad input"       # Logs only, doesn't exit
warn "warning message"             # Logs warning
success "task complete"            # Logs success
debug "debug info"                 # Logs if DEBUG=1
```

### Variable Declarations
```bash
# Declare and assign separately (shellcheck compliance)
local variable
variable=$(command)

readonly CONSTANT="value"
```

### File Naming
- Regular files: `filename.sh` - Loaded automatically
- Ignored files: `_filename.sh` - Skipped by loader
- Ignored folders: `_foldername/` - Entire folder skipped

---

## Common Pitfalls

### ❌ Using `error()` in Validation

```bash
# WRONG - exits the script:
if [[ -z "$hostname" ]]; then
    error "Hostname required"
fi

# CORRECT - logs and continues:
if [[ -z "$hostname" ]]; then
    validation_error "Hostname required"
    ((validation_errors++))
fi
```

### ❌ Not Returning Error Count

```bash
# WRONG:
mymodule_validate_callback() {
    local validation_errors=0
    ...
    # Missing return!
}

# CORRECT:
mymodule_validate_callback() {
    local validation_errors=0
    ...
    return "$validation_errors"
}
```

### ❌ Forgetting Module Registration

```bash
# WRONG - module won't be found:
# (no registration call)

# CORRECT - at end of module file:
config_register_module "mymodule" \
    "init_cb" "display_cb" "interactive_cb" "validate_cb"
```

---

## Environment Variable System

### How It Works

1. Every `config_set()` call registers the key in `CONFIG_KEYS`
2. After module init, `config_apply_env_overrides()` scans ALL registered keys
3. Checks for matching `DPS_*` environment variables
4. Applies overrides automatically

### Example

```bash
# In your action:
config_register_vars "$action" \
    "API_KEY:" \
    "CUSTOM_SETTING:default"

# User can set:
export DPS_API_KEY=secret123
export DPS_CUSTOM_SETTING=value

# Both are applied automatically!
```

---

## Debugging

### Enable Debug Mode
```bash
export DEBUG=1
./main.sh
```

Shows:
- Library loading (recursive)
- Module registration
- Environment variable application
- Config key registration
- Validation errors

### Test Validation

```bash
# Manually test validation:
config_init "$action" "network"

if ! config_validate "$action" "network"; then
    echo "Validation failed"
fi
```

---

## Library Organization

```
lib/
├── setupConfiguration.sh         # Config engine
├── setupConfiguration/           # Config modules
│   ├── network.sh
│   ├── disk.sh
│   └── custom.sh
├── inputValidation/              # Validators
│   ├── validation_network.sh
│   ├── validation_disk.sh
│   └── validation_common.sh
├── nixosSetup/                   # NixOS operations
│   ├── network.sh
│   ├── disk.sh
│   └── installation.sh
├── formatting.sh                 # Logging/UI
├── userInput.sh                  # Basic prompts
├── inputHelpers.sh               # Validation helpers
└── crypto.sh                     # Encryption/keys
```

**Loading:**
- Recursive loading from `lib/`
- Files/folders starting with `_` are ignored
- No manual sourcing needed

---

## Configuration Flow

```
Action calls config_init() for modules
  ↓
Modules register keys via config_set()
  ↓
config_apply_env_overrides() scans registered keys
  ↓
Applies DPS_* environment variable overrides
  ↓
config_workflow() runs validation → display → interactive → confirm
  ↓
If validation fails: Force interactive mode
  ↓
Action accesses config via config_get()
```

---

## Key Functions Reference

### Configuration
- `config_set(action, module, key, value)` - Set config value
- `config_get(action, module, key)` - Get config value
- `config_init(action, module)` - Initialize module
- `config_workflow(action, module1, module2, ...)` - Complete workflow
- `config_register_vars(action, "VAR:default", ...)` - Register custom vars
- `config_get_var(action, var)` - Get custom var value

### Validation Helpers
- `prompt_validated(label, current, validator, required, error_msg)`
- `prompt_bool(label, current)`
- `prompt_choice(label, current, options)`
- `prompt_number(label, current, min, max, required)`
- `update_if_changed(action, module, key, old, new)`

### Validators
- `validate_ip(ip)`, `validate_hostname(name)`, `validate_netmask(mask)`
- `validate_disk_path(path)`, `validate_disk_size(size)`
- `validate_yes_no(value)`, `validate_username(user)`, `validate_port(port)`

---

**See [README.md](README.md) for user-facing documentation and library function reference.**

**Version**: 4.0  
**Last Updated**: 2025-10-21
