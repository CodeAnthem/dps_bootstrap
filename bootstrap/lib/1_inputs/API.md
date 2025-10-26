# Input Handler API Reference

## Overview

Input handlers validate and transform user input for configuration fields. Each input type (e.g., `ip`, `hostname`, `toggle`) implements a standard API through optional functions.

---

## API Functions

### Required Functions

#### `validate_{input}(value)`

**Purpose:** Validate user input  
**Parameters:** `$1` - value to validate  
**Returns:**
- `0` - validation passed
- `1` - standard validation failure
- `2+` - specific error codes (optional)

**Example:**
```bash
validate_ip() {
    local ip="$1"
    [[ -z "$ip" ]] && return 1
    
    # Validation logic...
    local -a octets
    IFS='.' read -r -a octets <<< "$ip"
    (( ${#octets[@]} == 4 )) || return 1
    
    # Check each octet...
    return 0
}
```

---

### Optional Functions

#### `error_msg_{input}(value, code)`

**Purpose:** Return human-readable error message  
**Parameters:**
- `$1` - invalid value
- `$2` - error code from validate function (default: 0)

**Returns:** Error message string via stdout  
**When to implement:** When you want specific error messages

**Example:**
```bash
error_msg_timezone() {
    local value="$1"
    local code="${2:-0}"
    
    case "$code" in
        1) echo "Timezone '$value' not found in system database" ;;
        2) echo "timedatectl command not available" ;;
        3) echo "Failed to retrieve timezone list" ;;
        *) echo "Invalid timezone" ;;
    esac
}
```

---

#### `normalize_{input}(value)`

**Purpose:** Transform user input to canonical form BEFORE storage  
**Parameters:** `$1` - validated value  
**Returns:** Normalized value via stdout  
**When to implement:** When multiple input formats map to one canonical form

**Example:**
```bash
normalize_toggle() {
    local value="$1"
    case "${value,,}" in
        true|enabled|1) echo "true" ;;   # Store as "true"
        false|disabled|0) echo "false" ;; # Store as "false"
    esac
}
```

**Data Flow:**
```
User types: "enabled"
→ normalize_toggle() → "true"
→ Stored in CONFIG_DATA: "true"
```

---

#### `display_{input}(value)`

**Purpose:** Transform stored value FOR display only  
**Parameters:** `$1` - stored value  
**Returns:** Display-friendly value via stdout  
**When to implement:** When you want pretty formatting without changing stored data

**Example:**
```bash
display_toggle() {
    local value="$1"
    case "$value" in
        true) echo "✓" ;;    # Display checkmark
        false) echo "✗" ;;   # Display cross
        *) echo "$value" ;;  # Fallback
    esac
}
```

**Data Flow:**
```
Stored: "true"
→ display_toggle() → "✓"
→ Menu shows: "✓"

Prompt shows: "true" (NOT transformed - user needs to type actual value)
```

**Important:** `display_*()` is ONLY used in:
- ✅ `module_display()` - Configuration menu
- ❌ NOT in prompts `[current]` field
- ❌ NOT in "Updated: X → Y" messages

---

#### `prompt_{input}(display, current)`

**Purpose:** Custom prompt logic (overrides `generic_input_loop`)  
**Parameters:**
- `$1` - display name
- `$2` - current value

**Returns:** New value via stdout, empty string to keep current  
**When to implement:** Complex prompts (fuzzy search, lists, multi-step)

**Example:**
```bash
prompt_timezone() {
    local display="$1"
    local current="$2"
    
    while true; do
        printf "  %-20s [%s] (e.g., zurich, UTC): " "$display" "$current" >&2
        read -r value < /dev/tty
        
        # Empty - keep current
        [[ -z "$value" ]] && return 0
        
        # Fuzzy search logic...
        local matches
        matches=$(timedatectl list-timezones | grep -ci "$value")
        
        if [[ "$matches" -eq 1 ]]; then
            echo "$(timedatectl list-timezones | grep -i "$value")"
            return 0
        elif [[ "$matches" -gt 1 ]]; then
            console "    Multiple matches - be more specific"
        else
            console "    Error: No timezone matching '$value'"
        fi
    done
}
```

---

#### `prompt_hint_{input}()`

**Purpose:** Provide hint text for generic prompt  
**Parameters:** None (uses `INPUT_OPTIONS_CACHE` via `input_opt`)  
**Returns:** Hint string via stdout  
**When to implement:** To show examples or format hints

**Example:**
```bash
prompt_hint_toggle() {
    echo "(true/false, enabled/disabled)"
}

prompt_hint_int() {
    local min
    local max
    min=$(input_opt "min" "")
    max=$(input_opt "max" "")
    
    if [[ -n "$min" && -n "$max" ]]; then
        echo "($min-$max)"
    fi
}
```

**Output:**
```
  Enable Encryption [false] (true/false, enabled/disabled): 
  SSH Port          [22] (1-65535): 
```

---

## Complete Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ USER INPUT: "enabled"                                        │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─→ prompt_*() (optional)
                  │   Custom prompt UI with fuzzy search, lists, etc.
                  │
                  ├─→ validate_*() (required)
                  │   Returns: 0 (valid) or 1+ (error code)
                  │
                  ├─→ error_msg_*() (optional)
                  │   If validation failed: "Enter true, false, enabled..."
                  │
                  ├─→ normalize_*() (optional)
                  │   "enabled" → "true"
                  │
┌─────────────────▼───────────────────────────────────────────┐
│ CONFIG_DATA STORAGE: "true"                                  │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─→ display_*() (optional)
                  │   "true" → "✓" (menu only)
                  │
┌─────────────────▼───────────────────────────────────────────┐
│ DISPLAY TO USER                                              │
│   Prompt:    Enable Encryption [true]:     (actual value)    │
│   Menu:      > Enable Encryption: ✓        (pretty display)  │
└─────────────────────────────────────────────────────────────┘
```

---

## Context System

Input functions can access field options through the `input_opt` function:

```bash
validate_port() {
    local value="$1"
    local min
    local max
    min=$(input_opt "min" "1")      # Get min option, default 1
    max=$(input_opt "max" "65535")  # Get max option, default 65535
    
    [[ "$value" =~ ^[0-9]+$ ]] && (( value >= min && value <= max ))
}
```

**Available in field declaration:**
```bash
field_declare SSH_PORT \
    input=port \
    min=1024 \       # Custom option
    max=49151        # Custom option
```

**Context is set automatically** before calling validators, error messages, and prompt functions.

---

## Creating New Input Handlers

### Step 1: Create File

Create `bootstrap/lib/1_inputs/{category}/{input}.sh`

### Step 2: Add Header

```bash
#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-XX-XX | Modified: 2025-XX-XX
# Description:   Input Handler - {Name}
# Feature:       {Brief description}
# ==================================================================================================
```

### Step 3: Implement Required Functions

```bash
validate_{input}() {
    local value="$1"
    # Validation logic
    return 0  # or 1+
}
```

### Step 4: Implement Optional Functions

Only implement what you need:
- `error_msg_*` - for better error messages
- `normalize_*` - for canonical storage format
- `display_*` - for pretty display
- `prompt_*` - for custom UI
- `prompt_hint_*` - for format hints

### Step 5: Use in Module

```bash
field_declare MY_FIELD \
    display="My Field" \
    input={input} \    # Your input type
    required=true
```

**Done!** The system auto-discovers your input handler.

---

## Best Practices

1. **Keep validation pure** - No console output, just return codes
2. **Return meaningful codes** - 0=success, 1=standard fail, 2+=specific errors
3. **Document error codes** - In error_msg_* function
4. **normalize vs display** - normalize for storage, display for menu
5. **Quote variables** - Always: `"$var"` not `$var`
6. **Declare separately** - `local var; var=$(cmd)` not `local var=$(cmd)`
