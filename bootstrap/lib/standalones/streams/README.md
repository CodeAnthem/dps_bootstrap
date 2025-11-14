# Streams <!-- omit in toc -->

**Unified multi-channel output system with dynamic function generation**

Drop-in logging/debug system with 4 independent output channels (stdout, stderr, logger, debug). Predefined functions (`output`, `info`, `warn`, `error`, `fatal`, `pass`, `fail`, `debug`) with routing, file output, emoji suppression, and dynamic function creation. Zero dependencies, pure Bash, hardened against format string injection.

## Overview <!-- omit in toc -->

- **🚀 Dynamic function generation** - Functions rebuilt on config changes, zero runtime overhead
- **📡 Multi-channel routing** - 4 channels (stdout/fd1, stderr/fd2, logger/fd3, debug/fd4)
- **🔒 Hardened security** - Protected against format string injection (%, quotes, etc.)
- **🎯 8 predefined functions** - output, info, warn, error, fatal, pass, fail, debug
- **🔧 Custom functions** - Create your own with custom emoji, tag, channel, exit code
- **📝 Dual output** - Console + file simultaneously per channel
- **🎨 Full customization** - Emoji, tag, timestamp, datestamp, indent
- **🚫 NOP control** - Enable/disable functions at runtime (zero overhead when disabled)
- **🧠 Smart defaults** - Auto-shows caller context when no message provided
- **📦 Single config array** - One associative array for all settings

## Table of Contents <!-- omit in toc -->
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Channel Configuration](#channel-configuration)
  - [Format Configuration](#format-configuration)
  - [Function Management](#function-management)
  - [Predefined Functions](#predefined-functions)
- [Usage Examples](#usage-examples)
  - [Basic Usage](#basic-usage)
  - [File Output](#file-output)
  - [Custom Functions](#custom-functions)
  - [Enable/Disable Functions](#enabledisable-functions)
  - [Format Customization](#format-customization)
  - [Channel Routing](#channel-routing)
  - [Exit Codes](#exit-codes)
  - [Default Message Feature](#default-message-feature)
- [Architecture](#architecture)
  - [Channels](#channels)
  - [Function Attributes](#function-attributes)
  - [Security Hardening](#security-hardening)
- [Performance](#performance)
- [Tests](#tests)

## Requirements
- **Bash 4.2+** (for associative arrays and `printf %(...)T` timestamp format)

## Quick Start

```bash
source streams.sh  # Auto-initializes all 8 functions

# Use predefined functions immediately
output "Goes to stdout"
info "Goes to logger (fd3)"
warn "Goes to logger (fd3)"
error "Goes to stderr (fd2)"
fatal "Goes to stderr and exits with code 1"
pass "Success message (fd3)"
fail "Failure message (fd3)"
debug "Hidden by default (debug starts as NOP)"

# Enable debug
stream_function debug --enable
debug "Now visible on fd4"

# Set file output
stream_set_channel logger --file-path "./app.log"
info "This goes to fd3 AND app.log"
```

## API Reference

### Channel Configuration

**`stream_set_channel [channel] [options]`** - Configure channel routing

| Option | Description | Values |
|--------|-------------|--------|
| `--console BOOL` | Enable/disable console output | `1/0`, `true/false`, `on/off` |
| `--file BOOL` | Enable/disable file output | `1/0`, `true/false`, `on/off` |
| `--file-path PATH` | Set file path for this channel | File path or `""` to clear |

**Channel names:** `stdout`, `stderr`, `logger`, `debug`  
**Omit channel** to apply to all channels.

**Examples:**
```bash
# Single channel
stream_set_channel logger --file-path "./logs/app.log"

# All channels
stream_set_channel --file-path "./logs/all.log"

# Disable console for debug channel
stream_set_channel debug --console 0

# Clear file path
stream_set_channel logger --file-path ""
```

**Safety:** Cannot disable console output on `stdout` channel (returns error).

### Format Configuration

**`stream_set_format [console|file] [options]`** - Configure output formatting

| Option | Description | Values |
|--------|-------------|--------|
| `--date BOOL` | Show date in timestamp | `1/0`, `true/false`, `on/off` |
| `--time BOOL` | Show time in timestamp | `1/0`, `true/false`, `on/off` |
| `--indent NUM` | Leading spaces (console only) | Number >= 0 |
| `--suppress-emojis BOOL` | Hide all emojis | `1/0`, `true/false`, `on/off` |

**Targets:** `console` (screen output), `file` (file output)  
**Omit target** for `--suppress-emojis` (global setting).

**Examples:**
```bash
# Console only
stream_set_format console --date 0 --time 1

# File only
stream_set_format file --date 1 --time 1

# Global emoji suppression
stream_set_format --suppress-emojis 1

# Multiple options
stream_set_format console --time 0 --indent 3
```

### Function Management

**`stream_function <name> [options]`** - Create or configure functions

| Option | Description | Values |
|--------|-------------|--------|
| `--emoji STRING` | Set emoji prefix | Any string |
| `--tag STRING` | Set tag prefix | Any string (uppercase func name if empty) |
| `--channel NAME` | Route to channel | `stdout`, `stderr`, `logger`, `debug` |
| `--exit CODE` | Exit code after output | Number or `-1` for no exit |
| `--enable` | Enable function (remove NOP) | - |
| `--disable` | Disable function (make NOP) | - |

**Examples:**
```bash
# Create custom function
stream_function "trace" --emoji " 🔍" --tag " [TRACE] -" --channel "debug" --exit -1

# Enable existing function
stream_function debug --enable

# Disable function (becomes no-op)
stream_function warn --disable

# Modify existing function
stream_function info --emoji " ✨"
```

### Predefined Functions

| Function | Channel | Exit Code | Default State | Description |
|----------|---------|-----------|---------------|-------------|
| `output` | stdout (fd1) | -1 (no exit) | Enabled | Plain output |
| `info` | logger (fd3) | -1 | Enabled | Info messages |
| `warn` | logger (fd3) | -1 | Enabled | Warnings |
| `error` | stderr (fd2) | -1 | Enabled | Errors |
| `fatal` | stderr (fd2) | 1 | Enabled | Fatal + exit 1 |
| `pass` | logger (fd3) | -1 | Enabled | Success/pass |
| `fail` | logger (fd3) | -1 | Enabled | Failure messages |
| `debug` | debug (fd4) | -1 | **Disabled** (NOP) | Debug output |

## Usage Examples

### Basic Usage

```bash
source streams.sh

output "Simple stdout message"
info "Application started"
warn "Configuration missing, using defaults"
error "Failed to load module"
pass "All tests passed"
fail "Validation failed"

# Fatal stops execution
fatal "Critical error - cannot continue"
```

### File Output

```bash
source streams.sh

# Single channel to file
stream_set_channel logger --file-path "./app.log"
info "Logged to file AND console"

# All channels to file
stream_set_channel --file-path "./all.log"
output "Everything goes to all.log"
error "Including errors"

# Dual paths per channel
stream_set_channel logger --file-path "./info.log"
stream_set_channel stderr --file-path "./errors.log"
info "Goes to info.log"
error "Goes to errors.log"
```

### Custom Functions

```bash
source streams.sh

# Create custom trace function on debug channel
stream_function "trace" \
    --emoji " 🔍" \
    --tag " [TRACE] -" \
    --channel "debug" \
    --exit -1

# Enable it (debug channel functions start as NOP)
stream_function trace --enable

trace "Detailed trace information"

# Create custom success with exit code
stream_function "success_exit" \
    --emoji " ✅" \
    --tag " [SUCCESS] -" \
    --channel "stdout" \
    --exit 0

success_exit "Operation completed successfully"  # exits with 0
```

### Enable/Disable Functions

```bash
source streams.sh

# Debug starts disabled (NOP)
debug "Won't show"

# Enable debug
stream_function debug --enable
debug "Now shows on fd4"

# Disable any function temporarily
stream_function warn --disable
warn "This won't execute (zero overhead)"

# Re-enable
stream_function warn --enable
warn "Back to normal"
```

### Format Customization

```bash
source streams.sh

# Show timestamp without date
stream_set_format console --date 0 --time 1
info "15:30:45 ℹ️  [INFO] - With time only"

# Remove timestamps completely
stream_set_format console --date 0 --time 0
info "ℹ️  [INFO] - No timestamp"

# Add indentation
stream_set_format console --indent 5
info "     ℹ️  [INFO] - Indented 5 spaces"

# Suppress all emojis globally
stream_set_format --suppress-emojis 1
info "[INFO] - No emoji"

# File format differs from console
stream_set_format console --date 0 --time 1
stream_set_format file --date 1 --time 1
stream_set_channel logger --file-path "./app.log"
info "Console: time only, File: date+time"
```

### Channel Routing

```bash
source streams.sh

# Disable console output for debug channel
stream_set_channel debug --console 0 --file-path "./debug.log"
stream_function debug --enable
debug "Only in file, not on screen"

# Route everything to files, disable console
stream_set_channel stdout --console 0 --file-path "./stdout.log"
stream_set_channel stderr --console 0 --file-path "./stderr.log"
stream_set_channel logger --console 0 --file-path "./logger.log"
stream_set_channel debug --console 0 --file-path "./debug.log"

# Now all output only goes to files
```

**Note:** Cannot disable console on `stdout` channel (safety check).

### Exit Codes

```bash
source streams.sh

# Fatal exits with code 1
fatal "Critical error"  # Script stops here with exit 1

# Custom exit code
stream_function "abort" --emoji " ❌" --tag " [ABORT] -" --channel "stderr" --exit 42
abort "Custom exit"  # Exits with code 42

# Test in subshell
(error "Normal error")  # Doesn't exit
echo $?  # Still running

(fatal "Fatal")  # Exits subshell
echo $?  # Returns 1
```

### Default Message Feature

```bash
source streams.sh

# Call without message - shows caller context
info
# Output: 2025-11-13 17:30:45 ℹ️  [INFO] - <No message> - main()#42 in myscript.sh

# Useful for quick debugging
function my_function() {
    debug  # Shows where it was called from
    # Output: 🐛 [DEBUG] - <No message> - my_function()#15 in script.sh
}
```

## Architecture

### Channels

| Channel | FD | Default Console | Default File | Purpose |
|---------|----|-----------------|--------------| --------|
| stdout | 1 | ✓ | ✗ | Standard output |
| stderr | 2 | ✓ | ✗ | Error output |
| logger | 3 | ✓ | ✓ | Application logging |
| debug | 4 | ✓ | ✓ | Debug output |

**FD Initialization:** FD3 and FD4 are opened as duplicates of stderr (`exec 3>&2; exec 4>&2`) on source. This is safe for interactive shells and works in subshells.

### Function Attributes

Each function has:
- **emoji** - Prefix icon (can be empty)
- **tag** - Text label (e.g., `[INFO] -`)
- **channel** - Output destination (stdout/stderr/logger/debug)
- **exit** - Exit code (-1 = no exit)
- **nop** - Boolean flag (1 = disabled/no-op, 0 = enabled)

### Security Hardening

The implementation protects against format string injection:

**% Escaping:**
```bash
# User-supplied content with % is escaped
stream_function "test" --tag "[TEST%100]"
# Internal: % → %% to prevent printf format injection
```

**Quote Protection:**
```bash
# Single quotes in tags are handled safely
stream_function "test" --tag "[IT'S OK]"
# Uses printf '%q' for shell-safe escaping
```

**Command printf --:**
```bash
# Generated functions use 'command printf --' to avoid:
# - Function shadowing (command forces builtin)
# - Option parsing (-n, -v, etc.)
```

**Message Safety:**
- Messages are always passed as `%s` arguments, never embedded in format strings
- No user input is evaluated or executed

## Performance

**Generated Function Example:**
```bash
# After: stream_function debug --enable
# Generated:
debug() {
    command printf -- '%(%Y-%m-%d %H:%M:%S)T 🐛 [DEBUG] - %s\n' -1 "${1:-...}" >&4
}
```

**Characteristics:**
- **Zero runtime conditionals** - All routing/formatting baked in at generation time
- **Direct printf** - No variable lookups, no function calls
- **Minimal overhead** - ~1 printf call per function invocation
- **NOP optimization** - Disabled functions are literal `: ;` (no-op)

**Cost of Changes:**
- Config changes trigger `__streams_defineFN_all` (regenerates all 8 functions)
- Takes ~0.002-0.003s (acceptable for infrequent config changes)
- Functions remain optimal after regeneration

## Tests

Run comprehensive test suite:
```bash
cd streams/
bash Test.sh
```

**Test Coverage:**
- Predefined functions
- Channel routing (all 4 channels)
- File output
- Format settings (timestamp, date, indent)
- Emoji suppression
- Custom function creation
- NOP enable/disable
- Exit codes
- Stdout safety check
- Combined settings
- Special characters (%, ', \, etc.)

**14 tests, 40+ assertions**
