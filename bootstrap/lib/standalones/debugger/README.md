# Debugger

**Conditional debug output with custom variable name support**

Drop-in debug system that only prints when enabled. Supports custom debug variable names, file output, and runtime toggling. Zero dependencies, pure Bash.

---

## Quick Start

```bash
# Standard usage (default variable: DEBUG)
source debugger.sh

debug "This won't show (debug disabled by default)"

debug_enable
debug "This will show"
debug_disable
```

**Custom Debug Variable Name:**

```bash
# Pass variable name as argument
source debugger.sh "NDS_DEBUG"

# Now the debugger uses NDS_DEBUG instead of DEBUG
export NDS_DEBUG=1
debug "This shows up"
```

---

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `debug <message>` | Print debug message (only when enabled) |
| `debug_enable` | Enable debug output |
| `debug_disable` | Disable debug output |
| `debug_toggle` | Toggle debug state |
| `debug_set <state>` | Set state: `true\|false\|1\|0\|on\|off` |
| `debug_is_enabled` | Check if enabled (returns 0=yes, 1=no) |

### Configuration Functions

| Function | Description |
|----------|-------------|
| `debug_init` | Reinitialize debug function (called automatically after config changes) |
| `debug_set_output_file <path>` | Write debug to file (empty=disable) |
| `debug_set_timestamp <1\|0>` | Enable/disable timestamp |
| `debug_set_datestamp <1\|0>` | Enable/disable date in timestamp (time only if off) |
| `debug_set_emoji <string>` | Set emoji prefix (default: " 🚧") |
| `debug_set_tag <string>` | Set tag prefix (default: " [DEBUG] -") |
| `debug_get_var_name` | Get current debug variable name |

---

## Usage Examples

### Basic Usage

```bash
source debugger.sh

debug_enable
debug "Starting application"

# Your code here
if [[ -f "config.txt" ]]; then
    debug "Config file found"
fi

debug_disable
```

### Custom Variable Name

```bash
# Pass variable name as argument
source debugger.sh "NDS_DEBUG"

# Now you can control with NDS_DEBUG instead of DEBUG
export NDS_DEBUG=1
./myscript.sh  # Debug will be enabled

# Or inline
NDS_DEBUG=1 ./myscript.sh
```

### Customize Output Format

```bash
source debugger.sh

# Change emoji
debug_set_emoji " 🔍"

# Change tag
debug_set_tag " [TRACE] -"

# Disable date (time only)
debug_set_datestamp 0

# Disable timestamp completely
debug_set_timestamp 0

debug_enable
debug "Custom formatted message"
# Output: 🔍 [TRACE] - Custom formatted message
```

### File Output

```bash
source debugger.sh

# Enable file output
debug_set_output_file "/tmp/myapp-debug.log"

debug_enable
debug "This goes to stderr AND /tmp/myapp-debug.log"

# Disable file output
debug_set_output_file ""
```

### Conditional Debugging

```bash
source debugger.sh

# Enable based on environment
[[ -n "$VERBOSE" ]] && debug_enable

# Enable from command line argument
while getopts "d" opt; do
    case $opt in
        d) debug_enable ;;
    esac
done

debug "Debug info..."
```

### Check State

```bash
source debugger.sh

if debug_is_enabled; then
    echo "Debug is ON"
    # Expensive debug operation
    debug "Full system state: $(get_system_info)"
fi
```

---

## Configuration

### Configuration Options

| Setting | Function | Default |
|---------|----------|---------|
| Variable name | Passed as argument to source | `DEBUG` |
| Timestamp | `debug_set_timestamp` | `1` (enabled) |
| Datestamp | `debug_set_datestamp` | `1` (show date) |
| Emoji | `debug_set_emoji` | `" 🚧"` |
| Tag | `debug_set_tag` | `" [DEBUG] -"` |

### Dynamic Variable Name

Pass the debug variable name as an argument when sourcing:

```bash
# Example 1: Use NDS_DEBUG
source debugger.sh "NDS_DEBUG"
export NDS_DEBUG=1

# Example 2: Use VERBOSE
source debugger.sh "VERBOSE"
export VERBOSE=1

# Example 3: Project-specific
source debugger.sh "MYAPP_DEBUG"
export MYAPP_DEBUG=1
```

**Why?** Prevents conflicts when multiple scripts/modules use different debug flags.

### Performance Optimization

The debugger uses **dynamic function generation** - the `debug()` function is rebuilt each time settings change:

- **Zero overhead when disabled** - just a single variable check
- **No repeated format checks** - output format is pre-built into function
- **File output baked in** - file writes included only when configured
- **Direct variable reference** - no indirect lookups (e.g., `${NDS_DEBUG}` not `${!var}`)

This means minimal performance impact even in tight loops.

---

## Output Format

Debug messages include timestamp and emoji:

```
 2025-11-12 15:30:45 🚧 [DEBUG] - Starting application
 2025-11-12 15:30:46 🚧 [DEBUG] - Processing file: data.txt
```

---

## Requirements

- **Bash 4.0+** (for indirect variable expansion)
- **Pure Bash** - no external dependencies

---

## License

Part of DPS Bootstrap - NixOS Deployment System
