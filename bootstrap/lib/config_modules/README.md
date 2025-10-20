# Configuration Modules - Developer Guide

## Overview

The new configuration system uses a **callback-based architecture** where modules only implement domain-specific logic, while the core engine handles all CRUD operations.

---

## Quick Start: Creating a New Module

### 1. Create Module File

```bash
touch bootstrap/lib/config_modules/mymodule.sh
```

### 2. Module Template

```bash
#!/usr/bin/env bash
# Module: mymodule
# Description: What this module does

# =============================================================================
# INITIALIZATION CALLBACK
# =============================================================================
mymodule_init_callback() {
    local action="$1"
    local module="$2"
    shift 2
    local config_pairs=("$@")
    
    # Define defaults
    local defaults=(
        "FIELD1:default_value"
        "FIELD2:value|option1|option2"  # With options
        "FIELD3:"  # Empty default
    )
    
    # Use provided config or defaults
    if [[ ${#config_pairs[@]} -eq 0 ]]; then
        config_pairs=("${defaults[@]}")
    fi
    
    # Parse and store
    for config_pair in "${config_pairs[@]}"; do
        local key="${config_pair%%:*}"
        local value_with_options="${config_pair#*:}"
        local default_value="${value_with_options%%|*}"
        local options="${value_with_options#*|}"
        
        # Store value
        config_set "$action" "$module" "$key" "$default_value"
        
        # Store options metadata (if any)
        if [[ "$options" != "$value_with_options" ]]; then
            config_set_meta "$action" "$module" "$key" "options" "$options"
        fi
        
        # Environment variable override (DPS_FIELD1 format)
        local env_var="DPS_${key}"
        if [[ -n "${!env_var:-}" ]]; then
            config_set "$action" "$module" "$key" "${!env_var}"
        fi
    done
}

# =============================================================================
# DISPLAY CALLBACK
# =============================================================================
mymodule_display_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module Configuration:"
    console "  FIELD1: $(config_get "$action" "$module" "FIELD1")"
    console "  FIELD2: $(config_get "$action" "$module" "FIELD2")"
    console "  FIELD3: $(config_get "$action" "$module" "FIELD3")"
}

# =============================================================================
# INTERACTIVE CALLBACK
# =============================================================================
mymodule_interactive_callback() {
    local action="$1"
    local module="$2"
    
    console "My Module Configuration:"
    
    # Field 1
    local field1
    field1=$(config_get "$action" "$module" "FIELD1")
    while true; do
        printf "  %-20s [%s]: " "FIELD1" "$field1"
        read -r new_value < /dev/tty
        
        if [[ -n "$new_value" ]]; then
            # Add validation here
            if validate_something "$new_value"; then
                if [[ "$new_value" != "$field1" ]]; then
                    config_set "$action" "$module" "FIELD1" "$new_value"
                    console "    -> Updated: FIELD1 = $new_value"
                    field1="$new_value"
                else
                    console "    -> Unchanged"
                fi
                break
            else
                console "    Error: Invalid value"
                continue
            fi
        elif [[ -n "$field1" ]]; then
            break
        else
            console "    Error: Field is required"
            continue
        fi
    done
    
    console ""
}

# =============================================================================
# VALIDATION CALLBACK
# =============================================================================
mymodule_validate_callback() {
    local action="$1"
    local module="$2"
    local validation_errors=0
    
    # Validate field1
    local field1
    field1=$(config_get "$action" "$module" "FIELD1")
    if [[ -z "$field1" ]]; then
        error "FIELD1 is required"
        ((validation_errors++))
    fi
    
    # More validation...
    
    return "$validation_errors"
}

# =============================================================================
# REGISTRATION (MUST BE AT END)
# =============================================================================
config_register_module "mymodule" \
    "mymodule_init_callback" \
    "mymodule_display_callback" \
    "mymodule_interactive_callback" \
    "mymodule_validate_callback"
```

### 3. Use in Action

```bash
# In your action's setup.sh:

setup() {
    local action_name="deployVM"
    
    # Initialize modules
    config_init "$action_name" "network"
    config_init "$action_name" "disk"
    config_init "$action_name" "mymodule"  # <-- Your new module
    
    # Run workflow (handles display, interactive, validate)
    config_workflow "$action_name" "network" "disk" "mymodule"
    
    # Get values
    local myvalue
    myvalue=$(config_get "$action_name" "mymodule" "FIELD1")
    
    echo "Field1 value: $myvalue"
}
```

---

## Core API Reference

### Configuration Storage

```bash
# Set a value
config_set "action" "module" "key" "value"

# Get a value
value=$(config_get "action" "module" "key")

# Set metadata (options, validation rules, etc.)
config_set_meta "action" "module" "key" "meta_type" "value"

# Get metadata
value=$(config_get_meta "action" "module" "key" "meta_type")

# Get all keys for a module
mapfile -t keys < <(config_get_keys "action" "module")

# Clear all config for action+module
config_clear "action" "module"
```

### Module Lifecycle

```bash
# Register a module (called by module itself)
config_register_module "module_name" \
    "init_callback" \
    "display_callback" \
    "interactive_callback" \
    "validate_callback"

# Initialize a module (called by action)
config_init "action" "module" ["key:value" ...]

# Display configuration
config_display "action" "module"

# Interactive editing
config_interactive "action" "module"

# Validate configuration
config_validate "action" "module"
```

### Workflow

```bash
# Complete workflow (recommended)
config_workflow "action" "module1" "module2" "module3"

# This handles:
# 1. Display all modules
# 2. Ask for modifications
# 3. Interactive editing (if yes)
# 4. Validation
# 5. Repeat until confirmed
```

---

## Validation Functions (validators.sh)

Available validators:

```bash
validate_ip "192.168.1.1"                    # IPv4 address
validate_netmask "255.255.255.0"             # Network mask or CIDR
validate_hostname "server-01"                # Hostname format
validate_disk_path "/dev/sda"                # Block device exists
validate_disk_size "8G" [allow_remaining]    # Size format
validate_yes_no "y"                          # Yes/no input
validate_port "22"                           # Port number 1-65535
validate_timezone "UTC"                      # Timezone
validate_username "admin"                    # Linux username
validate_file_path "/path/to/file"           # File exists
validate_choice "dhcp" "dhcp|static"         # Choice from options
convert_size_to_bytes "8G"                   # Convert to bytes
```

---

## Best Practices

### 1. Always Validate Input
```bash
if [[ -n "$new_value" ]]; then
    if validate_something "$new_value"; then
        # OK to set
    else
        console "    Error: Invalid value"
        continue
    fi
fi
```

### 2. Show "Unchanged" When Appropriate
```bash
if [[ "$new_value" != "$old_value" ]]; then
    config_set "$action" "$module" "KEY" "$new_value"
    console "    -> Updated: KEY = $new_value"
else
    console "    -> Unchanged"
fi
```

### 3. Use Options Metadata
```bash
# In init callback:
config_set_meta "$action" "$module" "METHOD" "options" "dhcp|static"

# In interactive callback:
local options
options=$(config_get_meta "$action" "$module" "METHOD" "options")
printf "  METHOD [%s] (%s): " "$current" "$options"
```

### 4. Break on Empty Input if Field Has Default
```bash
if [[ -n "$new_value" ]]; then
    # Process new value
elif [[ -n "$current_value" ]]; then
    break  # Keep current value
else
    console "    Error: Field is required"
    continue
fi
```

### 5. Conditional Fields
```bash
local method
method=$(config_get "$action" "$module" "METHOD")

if [[ "$method" == "static" ]]; then
    # Show static IP fields
fi
```

---

## Examples

See existing modules for complete examples:
- `network.sh` - IP configuration, conditional fields
- `disk.sh` - Complex nested settings, helpers
- `custom.sh` - Simple key-value pairs

---

## Troubleshooting

### Module Not Found
**Error**: `Module not registered: mymodule`

**Fix**: Ensure `config_register_module` is called at module load

### Values Not Persisting
**Issue**: Values disappear after setting

**Fix**: Use `config_set()` not `config_set_meta()`

### Validation Not Running
**Issue**: Invalid values accepted

**Fix**: Check validation callback returns error count, not boolean

---

## Migration from Old System

### Old Module Function → New Callback

| Old | New |
|-----|-----|
| `mymodule_config_init()` | `mymodule_init_callback()` |
| `mymodule_config_display()` | `mymodule_display_callback()` |
| `mymodule_config_interactive()` | `mymodule_interactive_callback()` |
| `mymodule_config_validate()` | `mymodule_validate_callback()` |
| `mymodule_config_get()` | `config_get("action", "mymodule", "key")` |
| `mymodule_config_set()` | `config_set("action", "mymodule", "key", "val")` |

### Old Array → New API

```bash
# Old
declare -A MYMODULE_CONFIG
MYMODULE_CONFIG["deployVM__KEY"]="value"
echo "${MYMODULE_CONFIG[deployVM__KEY]}"

# New
config_set "deployVM" "mymodule" "KEY" "value"
echo "$(config_get "deployVM" "mymodule" "KEY")"
```

---

## Summary

**To create a new module:**
1. Copy template above
2. Implement 4 callbacks
3. Register module at end
4. Add to action's workflow

**That's it!** No CRUD code needed - the engine handles everything.
