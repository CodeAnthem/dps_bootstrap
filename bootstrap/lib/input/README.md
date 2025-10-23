# Input System - Complete Architecture

## Overview

Clean, context-based input system with **domain-organized inputs** and **zero duplication**.

---

## Structure

```
bootstrap/lib/input/
├── network/
│   ├── ip.sh              # IP address validation
│   ├── port.sh            # Port with min/max range  
│   ├── mask.sh            # Network mask (CIDR or dotted)
│   └── hostname.sh        # RFC 1123 hostname
├── system/
│   ├── username.sh        # Linux username rules
│   ├── path.sh            # File/directory path
│   └── url.sh             # URL validation (http, https, git, ssh)
├── disk/
│   ├── disk.sh            # Disk selection with listing (custom prompt)
│   └── disk_size.sh       # Disk size format (8G, 500M, 1T)
├── time/
│   └── timezone.sh        # Timezone validation
└── primitive/
    ├── toggle.sh          # true/false, enabled/disabled
    ├── question.sh        # yes/no (for confirmations)
    ├── int.sh             # Integer with optional min/max
    ├── float.sh           # Floating point number
    ├── string.sh          # String with optional length/pattern
    └── choice.sh          # Multiple choice from options
```

---

## Core Concepts

### 1. Context-Based Options

Framework sets context before calling input functions. No parameter passing needed!

```bash
# Framework sets context
INPUT_CONTEXT_MODULE="network"
INPUT_CONTEXT_FIELD="SSH_PORT"
INPUT_OPTIONS_CACHE[min]="1024"
INPUT_OPTIONS_CACHE[max]="65535"

# Input accesses options via helper
local min=$(input_opt "min" "1")     # Gets 1024 from cache
local max=$(input_opt "max" "65535") # Gets 65535 from cache
```

### 2. Input File Pattern

Each input provides up to 4 optional functions:

```bash
# OPTIONAL: Hint shown in prompt
prompt_hint_inputname() {
    echo "(hint text)"
}

# REQUIRED: Validation logic
validate_inputname() {
    local value="$1"
    # validation logic
    return 0 or 1
}

# OPTIONAL: Transform input (e.g., "enabled" → "true")
normalize_inputname() {
    local value="$1"
    echo "normalized_value"
}

# OPTIONAL: Custom error message
error_msg_inputname() {
    echo "Custom error message"
}

# OPTIONAL: Override framework prompt (complex inputs only)
prompt_inputname() {
    local display="$1"
    local current="$2"
    # custom prompt logic
    echo "selected_value"
}
```

### 3. Framework Handles Everything

- **Read loop** - Framework handles `read`, empty input, validation, normalization
- **Error display** - Automatic error messages
- **Required check** - Framework checks after prompt
- **Option caching** - Options extracted once, available to all functions

---

## Usage Examples

### Simple Input (IP Address)

**Config Module:**
```bash
field_declare IP_ADDRESS \
    display="IP Address" \
    input=ip \
    required=true
```

**Input File (input/network/ip.sh):**
```bash
validate_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    [[ "$ip" =~ $ip_regex ]] || return 1
    
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        (( octet > 255 )) && return 1
    done
    return 0
}

error_msg_ip() {
    echo "Invalid IP address format (example: 192.168.1.1)"
}
```

**Result:**
```
  IP Address       []: 192.168.1.10
    -> Updated: IP_ADDRESS = 192.168.1.10
```

---

### Input with Options (Port)

**Config Module:**
```bash
field_declare SSH_PORT \
    display="SSH Port" \
    input=port \
    default="22" \
    required=true \
    min=1024 \
    max=65535
```

**Input File (input/network/port.sh):**
```bash
prompt_hint_port() {
    local min=$(input_opt "min" "1")
    local max=$(input_opt "max" "65535")
    echo "($min-$max)"
}

validate_port() {
    local value="$1"
    local min=$(input_opt "min" "1")
    local max=$(input_opt "max" "65535")
    
    [[ "$value" =~ ^[0-9]+$ ]] && (( value >= min && value <= max ))
}

error_msg_port() {
    local min=$(input_opt "min" "1")
    local max=$(input_opt "max" "65535")
    echo "Port must be a number between $min and $max"
}
```

**Result:**
```
  SSH Port         [22] (1024-65535): 8080
    -> Updated: SSH_PORT = 8080
```

---

### Normalized Input (Toggle)

**Config Module:**
```bash
field_declare ENCRYPTION \
    display="Enable Encryption" \
    input=toggle \
    default=true
```

**Input File (input/primitive/toggle.sh):**
```bash
prompt_hint_toggle() {
    echo "(true/false, enabled/disabled)"
}

validate_toggle() {
    local value="$1"
    [[ "${value,,}" =~ ^(true|false|enabled|disabled|1|0)$ ]]
}

normalize_toggle() {
    local value="$1"
    case "${value,,}" in
        true|enabled|1) echo "true" ;;
        false|disabled|0) echo "false" ;;
    esac
}
```

**Result:**
```
  Enable Encryption [true] (true/false, enabled/disabled): enabled
    -> Updated: ENCRYPTION = true
```

---

### Custom Prompt (Disk)

**Config Module:**
```bash
field_declare DISK_TARGET \
    display="Target Disk" \
    input=disk \
    default="/dev/sda" \
    required=true
```

**Input File (input/disk/disk.sh):**
```bash
# Custom prompt - overrides framework generic loop
prompt_disk() {
    local display="$1"
    local current="$2"
    
    # Show available disks
    console ""
    console "Available disks:"
    local available_disks
    mapfile -t available_disks < <(list_available_disks)
    
    for i in "${!available_disks[@]}"; do
        console "  $((i+1))) ${available_disks[i]}"
    done
    console ""
    
    while true; do
        printf "  %-20s [%s]: " "$display" "$current" >&2
        read -r value < /dev/tty
        
        # Check if it's a number (selection from list)
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            local selected_disk="${available_disks[$((value-1))]}"
            value="${selected_disk%% *}"
        fi
        
        if validate_disk "$value"; then
            echo "$value"
            return 0
        fi
    done
}

validate_disk() {
    [[ -b "$1" ]]
}
```

**Result:**
```
Available disks:
  1) /dev/sda (100G)
  2) /dev/nvme0n1 (500G)

  Target Disk      [/dev/sda]: 2
    -> Updated: DISK_TARGET = /dev/nvme0n1
```

---

## Available Options

### Common Options (all inputs)
- `default="value"` - Default value
- `required=true` - Field is required (default: false)
- `error="Custom error"` - Override error message
- `read_type="char"` - Single char read (default: "string")

### Input-Specific Options

**port, int:**
- `min=1024` - Minimum value
- `max=65535` - Maximum value

**string:**
- `minlen=5` - Minimum length
- `maxlen=50` - Maximum length
- `pattern="^[a-z]+$"` - Regex pattern

**choice:**
- `options="dhcp|static"` - Available choices (pipe-separated)

---

## Complete Input Reference

### Network Inputs
| Input | Purpose | Options |
|-------|---------|---------|
| `ip` | IPv4 address | - |
| `port` | Port number | min, max |
| `mask` | Network mask (CIDR or dotted) | - |
| `hostname` | RFC 1123 hostname | - |

### System Inputs
| Input | Purpose | Options |
|-------|---------|---------|
| `username` | Linux username | - |
| `path` | File/directory path | - |
| `url` | URL (http, https, git, ssh) | - |

### Disk Inputs
| Input | Purpose | Options |
|-------|---------|---------|
| `disk` | Block device selection | - |
| `disk_size` | Disk size (8G, 500M, 1T) | - |

### Time Inputs
| Input | Purpose | Options |
|-------|---------|---------|
| `timezone` | Timezone (UTC, Europe/Zurich) | - |

### Primitive Inputs
| Input | Purpose | Options |
|-------|---------|---------|
| `toggle` | true/false, enabled/disabled | - |
| `question` | yes/no (for confirmations) | - |
| `int` | Integer number | min, max |
| `float` | Floating point number | - |
| `string` | Text string | minlen, maxlen, pattern |
| `choice` | Multiple choice | options |

---

## Adding New Inputs

### 1. Create input file in appropriate domain

```bash
# input/mydomain/myinput.sh
validate_myinput() {
    local value="$1"
    # validation logic
}
```

### 2. Add optional functions as needed

```bash
prompt_hint_myinput() {
    echo "(hint)"
}

normalize_myinput() {
    echo "normalized"
}

error_msg_myinput() {
    echo "Custom error"
}
```

### 3. Use in config module

```bash
field_declare MY_FIELD \
    display="My Field" \
    input=myinput \
    required=true
```

**That's it!** Framework handles everything else.

---

## Benefits

✅ **Zero Duplication** - Options accessed once via context  
✅ **Clean Input Files** - Minimal code, focus on logic  
✅ **Consistent UX** - Framework handles all prompts uniformly  
✅ **Easy to Extend** - Just add new input file  
✅ **Self-Documenting** - Input name describes purpose  
✅ **Type Safety** - Each input validates its own format  
✅ **Reusable** - IP validator used 5 times, written once
