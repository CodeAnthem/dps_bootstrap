# Configuration System

Unified configuration management with module-based architecture, automatic environment variable overrides, and smart validation-first workflow.

---

## Features

- **Module-based** - Reusable config modules (network, disk, custom)
- **Environment overrides** - `DPS_*` vars automatically applied
- **Smart validation** - Only prompts for missing/invalid fields
- **Category menu** - Interactive editing by category with live preview
- **DPS_* scanning** - Any registered config key can be overridden via env vars

---

## How It Works

### Architecture

```
setupConfiguration.sh          # Core engine
├─ Module Registry             # Stores module callbacks
├─ Config Storage (CONFIG_DATA)# Single source of truth
├─ Key Registry (CONFIG_KEYS)  # Tracks all keys for env scanning
└─ Workflow Functions          # Orchestrates the flow

setupConfiguration/            # Config modules
├─ network.sh                  # Network config
├─ disk.sh                     # Disk config
└─ custom.sh                   # Custom vars
```

### Workflow

```
1. Action calls config_init() per module
2. Modules register keys → CONFIG_KEYS
3. config_workflow() called
4. Scans for DPS_* env vars → applies overrides
5. Validates all modules
6. IF errors → Fix only broken fields
7. Show config summary
8. User chooses: confirm or edit by category
9. Category menu: pick what to change, see live preview
10. Done → proceed
```

---

## API

### Core Functions

```bash
# Initialize module with defaults
config_init "action" "module"

# Run complete workflow (validate → fix errors → menu → confirm)
config_workflow "action" "module1" "module2" ...

# Get/Set config values
config_set "action" "module" "key" "value"
config_get "action" "module" "key"

# Register custom variables (bypasses modules)
config_register_vars "action" "VAR1:default" "VAR2:default2"
config_get_var "action" "VAR1"
```

### Module Registration

```bash
# Register a module (5 callbacks)
config_register_module "mymodule" \
    "init_callback" \
    "display_callback" \
    "interactive_callback" \
    "validate_callback" \
    "fix_errors_callback"  # Optional - falls back to interactive
```

### Callbacks

#### `init_callback(action, module, config_pairs...)`
Sets defaults, stores in CONFIG_DATA via `config_set()`.

#### `display_callback(action, module)`
Displays current config to user.

#### `interactive_callback(action, module)`
Prompts for ALL fields. Used when user selects category in menu.

#### `validate_callback(action, module)` → `error_count`
Validates config, returns number of errors (NOT boolean).

#### `fix_errors_callback(action, module)`
Prompts ONLY for invalid/missing fields. Much faster than interactive.

---

## Creating a Module

```bash
#!/usr/bin/env bash
# lib/setupConfiguration/mymodule.sh

# Init - set defaults
mymodule_init_callback() {
    local action="$1"
    local module="$2"
    
    config_set "$action" "$module" "SETTING1" "default"
    config_set "$action" "$module" "SETTING2" "value"
}

# Display - show config
mymodule_display_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module:"
    console "  SETTING1: $(config_get "$action" "$module" "SETTING1")"
    console "  SETTING2: $(config_get "$action" "$module" "SETTING2")"
}

# Interactive - prompt for ALL fields
mymodule_interactive_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module Configuration:"
    console ""
    
    local setting1=$(config_get "$action" "$module" "SETTING1")
    local new=$(prompt_validated "SETTING1" "$setting1" "validate_something" "required")
    update_if_changed "$action" "$module" "SETTING1" "$setting1" "$new"
    
    console ""
}

# Validate - return error count
mymodule_validate_callback() {
    local action="$1"
    local module="$2"
    local validation_errors=0
    
    local setting1=$(config_get "$action" "$module" "SETTING1")
    if [[ -z "$setting1" ]]; then
        validation_error "SETTING1 is required"
        ((validation_errors++))
    fi
    
    return "$validation_errors"
}

# Fix errors - ONLY prompt for broken fields
mymodule_fix_errors_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module Configuration:"
    console ""
    
    local setting1=$(config_get "$action" "$module" "SETTING1")
    if [[ -z "$setting1" ]] || ! validate_something "$setting1"; then
        local new=$(prompt_validated "SETTING1" "$setting1" "validate_something" "required")
        update_if_changed "$action" "$module" "SETTING1" "$setting1" "$new"
    fi
    
    console ""
}

# Register
config_register_module "mymodule" \
    "mymodule_init_callback" \
    "mymodule_display_callback" \
    "mymodule_interactive_callback" \
    "mymodule_validate_callback" \
    "mymodule_fix_errors_callback"
```

---

## Usage in Actions

```bash
#!/usr/bin/env bash
# actions/myaction/setup.sh

setup() {
    local action_name="$1"
    
    # Initialize modules
    config_init "$action_name" "network"
    config_init "$action_name" "disk"
    
    # Or register custom vars
    config_register_vars "$action_name" \
        "API_KEY:" \
        "ENDPOINT:https://api.example.com"
    
    # Run workflow (auto-applies DPS_* env vars)
    config_workflow "$action_name" "network" "disk"
    
    # Access config
    local hostname=$(config_get "$action_name" "network" "HOSTNAME")
    local api_key=$(config_get_var "$action_name" "API_KEY")
    
    # Deploy...
}
```

---

## Environment Variables

Any registered config key can be overridden:

```bash
export DPS_HOSTNAME=myserver
export DPS_ADMIN_USER=admin
export DPS_DISK_TARGET=/dev/nvme0n1
export DPS_API_KEY=secret123  # Even custom vars!

./start.sh
# All applied automatically, no prompts
```

---

## Input Helpers

Located in `../inputHelpers.sh`:

```bash
# Validated input
new=$(prompt_validated "LABEL" "$current" "validate_func" "required|optional" "Error msg")

# Boolean y/n
enabled=$(prompt_bool "ENABLE" "$current")

# Choice from options
method=$(prompt_choice "METHOD" "$current" "opt1|opt2|opt3")

# Number with range
port=$(prompt_number "PORT" "$current" 1 65535 "required")

# Update only if changed
update_if_changed "$action" "$module" "KEY" "$old" "$new"
```

---

## Key Points

- **fix_errors_callback is optional** - falls back to full interactive if missing
- **Validation must return error count** - not boolean
- **Use validation_error() not error()** - error() exits script
- **Keys auto-registered** - every config_set() registers key for env scanning
- **DPS_* vars applied automatically** - in config_workflow() before validation
- **Category menu validates before exit** - can't leave with errors

---

**WIP**: This system is under active development.
