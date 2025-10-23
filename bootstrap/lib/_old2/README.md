# Input System Architecture

## Overview
The input system is a **three-layer architecture** for handling user input in the DPS Bootstrap configuration workflow:

1. **Units** - Specialized input types with custom behavior
2. **Types** - Generic reusable prompt handlers
3. **Validation** - Standalone validator functions

---

## Philosophy

### The Problem
Previous architecture had prompts and validators scattered across multiple files, making it hard to:
- Find related functions (validator and prompt separated)
- Reuse validators across fields (IP address used in 5 places)
- Extend with new specialized types

### The Solution
**Unit-based architecture** with clear separation:
- **Units** = Complex specialized types (disk, timezone) with custom prompts
- **Types** = Simple generic prompts (text, bool, choice, number)
- **Validation** = Reusable validators (IP, hostname, port, username)

---

## Directory Structure

```
bootstrap/lib/input/
├── units/              # Specialized input types
│   ├── disk.sh         # Disk selection with device listing
│   └── timezone.sh     # Timezone validation
├── types/              # Generic prompt handlers
│   ├── text.sh         # Text input with validation
│   ├── bool.sh         # Yes/No prompting
│   ├── choice.sh       # Multiple choice selection
│   └── number.sh       # Numeric input
└── validation/         # Reusable validators
    ├── network.sh      # IP, hostname, netmask, port, subnet
    ├── system.sh       # Username, URL, path
    └── common.sh       # Nonempty, disk_size
```

---

## Usage Guide

### 1. Using Units (Specialized Types)

**When to use:** Field needs custom prompt behavior or complex validation.

**Example: Disk Selection**
```bash
field_declare DISK_TARGET \
    display="Target Disk" \
    required=true \
    default="/dev/sda" \
    unit=disk              # ← Uses units/disk.sh
```

**What happens:**
1. System loads `input/units/disk.sh`
2. Calls `prompt_disk()` which:
   - Lists available disks with sizes
   - Accepts numbered selection (1, 2, 3)
   - Accepts full path (/dev/sda)
   - Validates with `validate_disk_path()`

### 2. Using Types (Generic Prompts)

**When to use:** Standard input pattern with custom validator.

**Example: IP Address**
```bash
field_declare IP_ADDRESS \
    display="IP Address" \
    type=text \
    validator=validate_ip    # ← Reusable validator from validation/network.sh
```

**What happens:**
1. System uses `input/types/text.sh`
2. Calls `prompt_validated()` with:
   - Display label
   - Current value
   - Validator function (`validate_ip`)
   - Required/optional flag

**Available types:**
- `type=text` - Generic text with custom validator
- `type=bool` - Yes/no (y/n) input
- `type=choice` - Multiple choice from options
- `type=number` - Numeric input with validation

### 3. Using Validation (Standalone Validators)

**Validators are reusable functions** that can be used with `type=text` fields.

**Example: Multiple IP Fields**
```bash
# Gateway uses same validator as IP
field_declare GATEWAY \
    display="Gateway" \
    type=text \
    validator=validate_ip    # ← Reused from validation/network.sh

# DNS also uses same validator
field_declare DNS_PRIMARY \
    display="Primary DNS" \
    type=text \
    validator=validate_ip    # ← Same validator, different field
```

---

## Creating New Units

### When to Create a Unit
- Field needs **custom prompt behavior** (not just validation)
- Example: Disk listing, date picker, file browser

### Structure
```bash
# input/units/myunit.sh
#!/usr/bin/env bash

# Validator (required)
validate_myunit() {
    local value="$1"
    # Validation logic
    return 0  # or 1
}

# Custom prompt (optional - if not present, uses prompt_validated)
prompt_myunit() {
    local label="$1"
    local current="$2"
    
    # Custom prompting logic
    # Show menu, list options, etc.
    
    echo "$selected_value"
}
```

### Usage in Config Module
```bash
field_declare MY_FIELD \
    display="My Field" \
    unit=myunit          # ← References input/units/myunit.sh
```

---

## Creating New Validators

### When to Create a Validator
- Need to **validate input format** without custom prompt
- Validator will be **reused across multiple fields**
- Example: Email, phone number, semantic version

### Structure
```bash
# Add to input/validation/network.sh or create new file
validate_myformat() {
    local value="$1"
    [[ "$value" =~ ^pattern$ ]]
}
```

### Usage with Text Type
```bash
field_declare MY_FIELD \
    display="My Field" \
    type=text \
    validator=validate_myformat
```

---

## Decision Tree

```
Does field need custom prompt behavior?
│
├─ YES → Create/use UNIT
│         Example: disk (shows device list)
│
└─ NO → Use TYPE + VALIDATOR
          │
          ├─ Simple yes/no? → type=bool
          ├─ Multiple options? → type=choice
          ├─ Numeric input? → type=number
          └─ Text with validation? → type=text + validator=validate_xxx
```

---

## Examples

### Example 1: Reusable IP Validation
```bash
# All these fields use the SAME validator
field_declare IP_ADDRESS type=text validator=validate_ip
field_declare GATEWAY type=text validator=validate_ip
field_declare DNS_PRIMARY type=text validator=validate_ip
field_declare DNS_SECONDARY type=text validator=validate_ip
```

### Example 2: Disk with Custom Prompt
```bash
# Uses specialized unit with device listing
field_declare DISK_TARGET unit=disk
```

### Example 3: Timezone with Unit
```bash
# Uses unit for validation, but generic text prompt
field_declare TIMEZONE unit=timezone error="Invalid timezone"
```

### Example 4: Boolean Choice
```bash
# Uses built-in bool type
field_declare ENCRYPTION type=bool default=y
```

### Example 5: Multiple Choice
```bash
# Uses built-in choice type
field_declare NETWORK_METHOD type=choice options="dhcp|static"
```

---

## Architecture Benefits

### ✅ Co-location
Related functions (validate + prompt) live together in unit files.

### ✅ Reusability
Validators shared across multiple fields without duplication.

### ✅ Extensibility
Easy to add new units or validators without modifying core system.

### ✅ Clear Separation
- Units = specialized/complex
- Types = generic/simple
- Validation = reusable logic

### ✅ Discoverability
Clear file structure makes it easy to find validators and units.

---

## Migration Guide

### Old System
```bash
field_declare TIMEZONE \
    display="Timezone" \
    validator=validate_timezone \
    type=text
```

### New System
```bash
# Option 1: Use unit (if custom prompt exists)
field_declare TIMEZONE \
    display="Timezone" \
    unit=timezone

# Option 2: Use type + validator (no custom prompt)
field_declare TIMEZONE \
    display="Timezone" \
    type=text \
    validator=validate_timezone
```

---

## Loading Mechanism

1. **Automatic loading** - All .sh files in `input/` loaded by `main.sh`
2. **Lazy loading units** - Units loaded on-demand when field uses `unit=xxx`
3. **Validators always available** - Loaded at bootstrap startup

---

## Priority System

When `field_prompt()` processes a field:

1. **Check for unit** - If `unit=xxx`, load and use unit-specific prompt
2. **Check for custom prompt** - If unit has `prompt_xxx()`, use it
3. **Fallback to type** - Use generic type-based prompt (`type=text`, etc.)
4. **Default to text** - If no type specified, use `prompt_validated()`

---

## Contributing

When adding new functionality:

1. **New specialized behavior?** → Create unit in `units/`
2. **New validation pattern?** → Add validator to `validation/`
3. **New generic prompt type?** → Add to `types/` (rare)

Always prefer reusing existing validators over creating new ones.
