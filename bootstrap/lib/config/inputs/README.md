# Input Handlers

## Overview

Input handlers validate and transform user input for configuration fields. Each input type implements a standard API with optional functions for validation, transformation, error messages, and custom prompts.

---

## Available Input Handlers

### Network Inputs
| Input | Purpose | Example |
|-------|---------|---------|
| **ip** | IPv4 address validation | `192.168.1.10` |
| **hostname** | Hostname format validation | `myserver`, `server-01` |
| **mask** | Network mask (CIDR or dotted) | `24`, `255.255.255.0` |
| **port** | Port number with range | `22`, `8080` |

### System Inputs
| Input | Purpose | Example |
|-------|---------|---------|
| **timezone** | Timezone with fuzzy search | `UTC`, `zurich` → `Europe/Zurich` |
| **username** | Unix username validation | `admin`, `deploy-user` |
| **path** | File/directory path | `/root/.ssh/key`, `~/config` |
| **url** | URL validation | `https://github.com/user/repo.git` |

### Disk Inputs
| Input | Purpose | Example |
|-------|---------|---------|
| **disk** | Block device selection | `/dev/sda`, `/dev/nvme0n1` |
| **disk_size** | Disk size format | `8G`, `500M`, `1T` |

### Primitive Inputs
| Input | Purpose | Example |
|-------|---------|---------|
| **choice** | Multiple choice selection | `dhcp`, `static` |
| **string** | String with length constraints | Any text |
| **int** | Integer with range | `1024`, `65535` |
| **float** | Floating point number | `3.14`, `2.5` |
| **toggle** | Boolean toggle | `true`, `enabled` → stored as `true` |
| **question** | Yes/No confirmation | `yes`, `y` → stored as `yes` |

---

## Quick Start

### Using an Input in a Module

```bash
# In your module's init_callback:
field_declare HOSTNAME \
    display="Hostname" \
    input=hostname \      # ← Input type
    required=true

field_declare SSH_PORT \
    display="SSH Port" \
    input=port \          # ← Input type
    required=true \
    min=1024 \            # ← Input-specific options
    max=65535
```

### How It Works

1. **User prompted:**
   ```
   Hostname []: server-01
   SSH Port [22] (1024-65535): 2222
   ```

2. **Input validation:**
   - `validate_hostname("server-01")` → 0 (valid)
   - `validate_port("2222")` → 0 (valid)

3. **Value stored:**
   ```bash
   config_get "system" "HOSTNAME"   # → "server-01"
   config_get "system" "SSH_PORT"   # → "2222"
   ```

---

## API Reference

For complete API documentation, see **[API.md](./API.md)**

### Key API Functions

**Required:**
- `validate_{input}(value)` - Validate user input

**Optional:**
- `error_msg_{input}(value, code)` - Error messages
- `normalize_{input}(value)` - Transform before storage
- `display_{input}(value)` - Transform for display
- `prompt_{input}(display, current)` - Custom prompt
- `prompt_hint_{input}()` - Hint text

### Example: Toggle Input

```bash
# User types: "enabled"
validate_toggle("enabled") → 0 (valid)
normalize_toggle("enabled") → "true" (stored)
display_toggle("true") → "✓" (displayed in menu)
```

**Menu shows:**
```
> Enable Encryption: ✓
```

**Prompt shows:**
```
Enable Encryption [true] (true/false, enabled/disabled): 
```

---

## Data Flow

```
User Input
  ↓
validate_*() - Check if valid
  ↓
normalize_*() - Transform to canonical form
  ↓
CONFIG_DATA - Store value
  ↓
display_*() - Transform for menu display
  ↓
Show to User
```

---

## Creating New Inputs

See **[API.md](./API.md)** for step-by-step guide.

**Quick example:**
```bash
# 1. Create file: bootstrap/lib/1_inputs/custom/email.sh

validate_email() {
    local value="$1"
    [[ "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

error_msg_email() {
    echo "Invalid email format (example: user@example.com)"
}

# 2. Use in module:
field_declare ADMIN_EMAIL \
    display="Admin Email" \
    input=email \
    required=true
```

**Done!** The system auto-discovers your input handler.

---

## Architecture

Input handlers are the foundation of the configuration system:

```
Actions (setup.sh)
  ↓
Configuration Modules (modules/*.sh)
  ↓
Field Operations (field.sh)
  ↓
Input Handlers (1_inputs/*/*.sh) ← You are here
```

**Separation of concerns:**
- **Input handlers** - Validate and transform individual values
- **Fields** - Manage single configuration fields
- **Modules** - Group related fields and cross-field validation
- **Workflows** - User interaction and menu navigation

---

## Best Practices

1. **Keep validation pure** - No console output, just return codes
2. **Use error codes** - Return meaningful codes for different failures
3. **normalize vs display** - normalize for storage, display for menu
4. **Quote variables** - Always `"$var"` not `$var`
5. **Declare separately** - `local var; var=$(cmd)` when calling commands

See **[API.md](./API.md)** for complete best practices and patterns
