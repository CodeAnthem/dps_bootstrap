# Debugger <!-- omit in toc -->

**Conditional debug output with dynamic function generation**

Drop-in debug system that only prints when enabled. Extremely fast and efficient. Supports custom debug state variable name, file output, runtime toggling, and intelligent default messages. Zero dependencies, pure Bash.

## Overview <!-- omit in toc -->

- **🚀 Zero performance overhead when disabled** - `debug()` becomes literal no-op `:`
- **🏎️ Minimal performance impact when enabled** - even in tight loops.
- **🧠 Smart default messages** - Auto-shows caller context when no message provided
- **⚙️ Argument-based configuration** - Set multiple options in one call
- **🎯 State-based generation** - Functions rebuilt per state, no runtime checks
- **📝 File output** - Optional dual output to file + stderr
- **🎨 Customizable** - Emoji, tag, timestamp, datestamp, indent all configurable
- **🔧 Custom debug variable** - Use any variable name, avoid conflicts
- **📦 Minimal globals** - Single associative array for all config

---  
     
## Table of Contents <!-- omit in toc -->
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Functions](#functions)
  - [Options](#options)
- [Usage Examples](#usage-examples)
  - [Basic Usage](#basic-usage)
  - [Custom Variable Name](#custom-variable-name)
  - [Default Message Feature](#default-message-feature)
  - [Customize Output Format](#customize-output-format)
  - [File Output](#file-output)
  - [Custom Indentation](#custom-indentation)
  - [Conditional Debugging](#conditional-debugging)
  - [Check State](#check-state)
- [Performance Optimization](#performance-optimization)
    - [When Enabled:](#when-enabled)
    - [When Disabled:](#when-disabled)
- [Tests:](#tests)
- [Requirements](#requirements)
---

## Quick Start

**Standard Usage:**
```bash
source debugger.sh # Default variable: DEBUG - default state: disabled
debug "This won't show"
debug_enable
debug "This will show"


**Custom State Variable Name As Argument:**

```bash
# Pass variable name as argument
export MY_DEBUG=1 # 1 enables, 0 disables by default
source debugger.sh "MY_DEBUG" # Now the debugger uses MY_DEBUG instead of DEBUG
debug "This shows up"
```

**Why?** Prevents conflicts when multiple scripts/modules use different debug flags.

---

## API Reference

### Functions

| Function | Description |
|----------|-------------|
| `debug [message]` | Print debug message (only when enabled). If no message provided, shows caller info |
| `debug_enable [silent]` | Enable debug output. Pass "silent" to suppress confirmation |
| `debug_disable [silent]` | Disable debug output. Pass "silent" to suppress confirmation |
| `debug_toggle [silent]` | Toggle debug state. Pass "silent" to suppress confirmation |
| `debug_state <state> [silent]` | Set state: `true\|false\|1\|0\|on\|off\|enabled\|disabled` |
| `debug_is_enabled` | Check if enabled (returns 0=yes, 1=no) |
| `debug_get_state` | Get state as string: "enabled" or "disabled" |
| `debug_get_var_name` | Get current debug state variable name |

### Options

**`debug_set [options]`** - Configure multiple options at once

| Option | Description | Values |
|--------|-------------|--------|
| `--file PATH` | Set output file path (also: `--output`) | File path or empty to disable |
| `--timestamp BOOL` | Enable/disable timestamp | `1/0`, `true/false`, `on/off` |
| `--datestamp BOOL` | Enable/disable date in timestamp | `1/0`, `true/false`, `on/off` |
| `--emoji STRING` | Set emoji prefix | Any string (default: " 🚧") |
| `--tag STRING` | Set tag prefix | Any string (default: " [DEBUG] -") |
| `--indent NUMBER` | Set leading spaces | Number >= 0 (default: 1) |

**Examples:**
```bash
# Single option
debug_set --timestamp 0

# Multiple options at once
debug_set --file "./logs/debug.log" --timestamp 0 --indent 3
```

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

### Default Message Feature

```bash
# Call debug without message - shows caller info
debug
# Output: 2025-11-12 15:30:45 🚧 [DEBUG] - <No message was passed> - called from main()#42 in myscript.sh
```

### Customize Output Format

```bash
source debugger.sh

# Set multiple options at once (efficient - only reinitializes once)
debug_set --emoji " 🔍" --tag " [TRACE] -" --datestamp 0 --timestamp 1

debug_enable
# Output: 15:30:45 🔍 [TRACE] - Debug enabled

debug "Custom formatted message"
# Output: 15:30:45 🔍 [TRACE] - Custom formatted message

# Or disable timestamp completely
debug_set --timestamp 0
debug "No timestamp"
# Output: 🔍 [TRACE] - No timestamp
```

### File Output

```bash
source debugger.sh

# Enable file output
debug_set --file "/tmp/myapp-debug.log"

debug_enable
debug "This goes to stderr AND /tmp/myapp-debug.log"

# Disable file output
debug_set --file ""
```

### Custom Indentation

```bash
source debugger.sh

# Default has 1 space indent
debug_enable
debug "Default indent"
#  2025-11-12 15:30:45 🚧 [DEBUG] - Default indent
# ^ one space

# No indent
debug_set --indent 0
debug "No indent"
# 2025-11-12 15:30:45 🚧 [DEBUG] - No indent

# Five spaces
debug_set --indent 5
debug "Five spaces"
#      2025-11-12 15:30:45 🚧 [DEBUG] - Five spaces
# ^^^^^ five spaces
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

## Performance Optimization

The debugger uses **state-based dynamic function generation** - all functions are rebuilt when state changes:

#### When Enabled:
```bash
debug() {
    printf -v o ' %(%Y-%m-%d %H:%M:%S)T 🚧 [DEBUG] - %s\n' -1 "${1:-<default message>}"
    echo "$o" >&2
}
debug_is_enabled() { return 0; }
debug_get_state() { echo "enabled"; }
```

#### When Disabled:
```bash
debug() { :; }
debug_is_enabled() { return 1; }
debug_get_state() { echo "disabled"; }
```

---

## Tests:
```bash
bash Test.sh

# Expected output:
# ...
```

## Requirements
- **Bash 4.0+** (for associative arrays and indirect variable expansion)
- **Pure Bash** - no external dependencies

---
