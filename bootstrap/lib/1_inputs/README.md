# Input Validators - Error Code Pattern

## Overview

Input validators return error codes to provide detailed error messages while keeping validation logic clean and silent.

## Pattern

### Validation Function
```bash
validate_input_name() {
    local value="$1"
    
    # Validation logic
    [[ -z "$value" ]] && return 1           # Empty value
    [[ ! condition ]] && return 2           # Specific failure  
    command || return 3                      # Command failure
    
    return 0  # Success
}
```

### Error Message Function
```bash
error_msg_input_name() {
    local value="$1"
    local code="${2:-0}"  # Error code (optional for backwards compat)
    
    case "$code" in
        1) echo "Value cannot be empty" ;;
        2) echo "Specific error message for failure case" ;;
        3) echo "Command failed or resource unavailable" ;;
        *) echo "Invalid input (generic fallback)" ;;
    esac
}
```

## Error Code Conventions

| Code | Meaning | Example |
|------|---------|---------|
| **0** | Success | Validation passed |
| **1** | Invalid format/value | Not matching expected pattern |
| **2** | System/resource issue | Command not available, file not found |
| **3** | External failure | Command execution failed |
| **4+** | Input-specific errors | Custom error cases |

## Benefits

### ✅ Clean Separation
- Validation logic stays pure (no echo/console calls)
- Error messages centralized in one function
- Easy to test validation without UI

### ✅ Detailed Feedback
- Different error codes → different messages
- User gets specific guidance
- Debugging easier

### ✅ Backwards Compatible
- Error code parameter is optional: `"${2:-0}"`
- Old code calling `error_msg_input()` still works
- Can migrate inputs gradually

## Examples

### Example 1: Complex Validator (Multiple Error Codes)

**Timezone** - Different failure modes need different messages

```bash
validate_timezone() {
    local tz="$1"
    
    [[ -z "$tz" ]] && return 1  # Empty
    
    if ! command -v timedatectl &>/dev/null; then
        return 2  # Command not available
    fi
    
    local timezones
    timezones=$(timedatectl list-timezones 2>/dev/null) || return 3  # Command failed
    
    grep -qxi "$tz" <<< "$timezones" && return 0
    
    return 1  # Not found
}

error_msg_timezone() {
    local value="$1"
    local code="${2:-0}"
    
    case "$code" in
        1) echo "Timezone '$value' not found in system timezone database" ;;
        2) echo "timedatectl command not available (required for timezone validation)" ;;
        3) echo "Failed to retrieve timezone list from timedatectl" ;;
        *) echo "Invalid timezone (examples: UTC, Europe/Zurich, America/New_York)" ;;
    esac
}
```

### Example 2: Simple Validator (Single Error Mode)

**IP Address** - Only one failure mode (invalid format)

```bash
validate_ip() {
    local ip="$1"
    local IFS=.
    local -a octets
    
    read -r -a octets <<< "$ip"
    (( ${#octets[@]} == 4 )) || return 1
    
    # Validate each octet...
    return 0
}

error_msg_ip() {
    local value="$1"
    local code="${2:-0}"  # Accept but don't use
    
    # Simple validator - only one failure mode
    echo "Invalid IP address format (example: 192.168.1.1)"
}
```

### Example 3: Validator with Context

**Choice** - Uses INPUT_OPTIONS_CACHE for validation

```bash
validate_choice() {
    local value="$1"
    local options
    options=$(input_opt "options" "")
    
    [[ -z "$options" ]] && return 2  # No options configured
    
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        [[ "$value" == "$choice" ]] && return 0
    done
    
    return 1  # Not in list
}

error_msg_choice() {
    local value="$1"
    local code="${2:-0}"
    local options
    options=$(input_opt "options" "")
    
    case "$code" in
        2) echo "No options configured for choice input" ;;
        *) echo "Options: ${options//|/, }" ;;
    esac
}
```

## Guidelines

### When to Use Error Codes

**✅ Use error codes when:**
- Multiple failure modes exist
- Different errors need different messages
- System dependencies may fail
- You want detailed user feedback

**❌ Keep it simple when:**
- Single failure mode (e.g., regex mismatch)
- Error message is always the same
- No external dependencies

### Simple Input Example (No Error Codes Needed)

```bash
validate_string() {
    local value="$1"
    [[ -n "$value" ]]  # Just check non-empty
}

error_msg_string() {
    echo "String cannot be empty"
    # No need for error codes - only one failure mode
}
```

## Migration Guide

### Step 1: Update Validation
Add return codes for different failure cases

### Step 2: Update Error Message
Add error code parameter and case statement

### Step 3: Test
Run test suite to verify error codes work

## Integration with Configuration System

The configuration system (`2_configuration/field.sh`) automatically:
1. Captures error code from validation: `error_code=$?`
2. Passes to error_msg: `error_msg_input "$value" "$error_code"`
3. Displays specific message to user

No changes needed in calling code!

## Current Implementation Status

### Network Inputs
| Input | Error Codes | Status |
|-------|-------------|--------|
| **ip** | 1=invalid | ✅ Backwards compatible |
| **hostname** | 1=invalid | ✅ Backwards compatible |
| **mask** | 1=invalid | ✅ Backwards compatible |
| **port** | 1=invalid | ✅ Backwards compatible |

### System Inputs
| Input | Error Codes | Status |
|-------|-------------|--------|
| **timezone** | 1=not found, 2=no command, 3=failed | ✅ **Full implementation** |
| **username** | 1=invalid | ✅ Backwards compatible |
| **path** | 1=invalid | ✅ Backwards compatible |
| **url** | 1=invalid | ✅ Backwards compatible |

### Disk Inputs
| Input | Error Codes | Status |
|-------|-------------|--------|
| **disk** | 1=invalid | ✅ Backwards compatible |
| **disk_size** | 1=invalid | ✅ Backwards compatible |

### Primitive Inputs
| Input | Error Codes | Status |
|-------|-------------|--------|
| **choice** | 1=not in list, 2=no options | ✅ Backwards compatible |
| **string** | 1=invalid | ✅ Backwards compatible |
| **int** | 1=invalid | ✅ Backwards compatible |
| **float** | 1=invalid | ✅ Backwards compatible |
| **toggle** | 1=invalid | ✅ Backwards compatible |
| **question** | 1=invalid | ✅ Backwards compatible |

**All 16 input validators now follow the error code pattern!** 🎯

## Best Practices

1. **Return 0 for success** - Always explicit
2. **Return 1 for invalid value** - Standard failure
3. **Return 2+ for system issues** - Helps debugging
4. **Document error codes** - Comment what each means
5. **Provide fallback message** - `*)` case in error_msg
6. **Make code optional** - `"${2:-0}"` for backwards compat
7. **Keep validation pure** - No output, just return codes
