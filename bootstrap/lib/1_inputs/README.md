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

## Example: Timezone Validator

### Before (Mixed Concerns)
```bash
validate_timezone() {
    local tz="$1"
    
    if ! command -v timedatectl &>/dev/null; then
        # ERROR: Validation contains error message logic!
        return 1
    fi
    
    timedatectl list-timezones | grep -qxi "$tz"  # Race condition!
}

error_msg_timezone() {
    echo "Invalid timezone"  # Generic, not helpful
}
```

### After (Clean + Detailed)
```bash
validate_timezone() {
    local tz="$1"
    
    [[ -z "$tz" ]] && return 1
    
    # NixOS always has timedatectl
    if ! command -v timedatectl &>/dev/null; then
        return 2  # Command not available
    fi
    
    # Avoid pipe race condition
    local timezones
    timezones=$(timedatectl list-timezones 2>/dev/null) || return 3
    
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

## Best Practices

1. **Return 0 for success** - Always explicit
2. **Return 1 for invalid value** - Standard failure
3. **Return 2+ for system issues** - Helps debugging
4. **Document error codes** - Comment what each means
5. **Provide fallback message** - `*)` case in error_msg
6. **Make code optional** - `"${2:-0}"` for backwards compat
7. **Keep validation pure** - No output, just return codes
