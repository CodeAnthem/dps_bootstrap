# Streams <!-- omit in toc -->

**Unified multi-channel output system with dynamic function generation**

Drop-in logging/debug system with 4 independent output channels. 9 predefined functions including special `output()` (echo-like), `log`, `info`, `warn`, `error`, `fatal`, `pass`, `fail`, `debug` with routing, file output, emoji suppression, and custom function creation. Zero dependencies, pure Bash.

## Overview <!-- omit in toc -->

- **🚀 Dynamic function generation** - Functions rebuilt on config changes, zero runtime overhead
- **📡 Multi-channel routing** - 4 channels (stdout/fd1, stderr/fd2, logger/fd3, debug/fd4)
- **🎯 9 predefined functions** - output, log, info, warn, error, fatal, pass, fail, debug
- **📤 Special output()** - Echo-like console output with optional formatted file logging
- **🔧 Custom functions** - Create your own with custom emoji, tag, channel, exit code
- **📝 Dual output** - Console + file simultaneously per channel
- **🎨 Full customization** - Emoji, tag, timestamp, datestamp, indent
- **🚫 NOP control** - Enable/disable functions at runtime (zero overhead when disabled)
- **🧠 Smart defaults** - Auto-shows caller context when no message provided

## Table of Contents <!-- omit in toc -->
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Functions](#functions)
  - [Options](#options)
- [Usage Examples](#usage-examples)
  - [Basic Usage](#basic-usage)
  - [File Output](#file-output)
  - [Custom Functions](#custom-functions)
  - [Format Customization](#format-customization)
  - [Default Message Feature](#default-message-feature)
  - [Cleanup](#cleanup)
- [Performance](#performance)
- [Tests](#tests)

## Requirements
- **Bash 4.2+** (for associative arrays and `printf %(...)T` timestamp format)

## Quick Start

```bash
source streams.sh  # Auto-initializes all 9 functions

# Plain echo-like output
output "Plain text to stdout"

# Formatted logging
log "Stdout with timestamp/emoji"
info "Application started"  # logger channel (fd3)
warn "Using defaults"       # logger channel (fd3)
error "Failed to load"      # stderr (fd2)
fatal "Cannot continue"     # stderr + exit 1

# Enable debug (starts disabled)
stream_function debug --enable
debug "Debug info"  # debug channel (fd4)

# File output
stream_set_channel logger --file-path "./app.log"
info "Goes to console AND app.log"
```

## API Reference

### Functions

**Channel Configuration:**
```bash
stream_set_channel [channel] [--console 0/1] [--file 0/1] [--file-path PATH]
```
- **Channels:** `stdout`, `stderr`, `logger`, `debug` (omit for all)
- **Safety:** Cannot disable console on `stdout` channel

**Format Configuration:**
```bash
stream_set_format [console|file] [--date 0/1] [--time 0/1] [--indent NUM]
stream_set_format --suppress-emojis 0/1
```
- **Targets:** `console`, `file` (omit target for `--suppress-emojis`)

**Function Management:**
```bash
stream_function <name> [--emoji STR] [--tag STR] [--channel NAME] [--exit CODE] [--enable|--disable]
```
- **Channels:** `stdout`, `stderr`, `logger`, `debug`
- **Exit:** Number or `-1` for no exit

**Cleanup:**
```bash
stream_cleanup
```
- Closes all opened FDs (3-9) and clears registry
- Typically called at script exit or when streams no longer needed

### Options

| Function | Channel | Description |
|----------|---------|-------------|
| `output` | stdout (fd1) | **Special:** `echo`-like console, formatted file logging |
| `log` | stdout (fd1) | Formatted stdout |
| `info` | logger (fd3) | Info messages |
| `warn` | logger (fd3) | Warnings |
| `error` | stderr (fd2) | Errors |
| `fatal` | stderr (fd2) | Fatal error + exit 1 |
| `pass` | logger (fd3) | Success messages |
| `fail` | logger (fd3) | Failure messages |
| `debug` | debug (fd4) | Debug output (disabled by default) |

**Note:** `output()` uses `echo "$@"` for console (no formatting), but writes formatted (timestamp, etc.) to file if enabled.

## Usage Examples

### Basic Usage

```bash
source streams.sh

output "Plain text"              # echo-like
log "Formatted message"          # with timestamp/emoji
info "Application started"
warn "Using defaults"
error "Failed to load"
fatal "Cannot continue"          # exits with 1
```

### File Output

```bash
# Single channel
stream_set_channel logger --file-path "./app.log"
info "Goes to console AND app.log"

# All channels
stream_set_channel --file-path "./all.log"

# Multiple files
stream_set_channel logger --file-path "./info.log"
stream_set_channel stderr --file-path "./errors.log"
```

### Custom Functions

```bash
# Create trace function
stream_function "trace" --emoji " 🔍" --tag " [TRACE] -" --channel "debug"
stream_function trace --enable
trace "Detailed info"

# Custom exit code
stream_function "abort" --emoji " ❌" --tag " [ABORT] -" --exit 42
abort "Custom exit"  # exits with 42

# Enable/disable
stream_function warn --disable
warn "Won't show (zero overhead)"
stream_function warn --enable
```

### Format Customization

```bash
# Timestamps
stream_set_format console --date 0 --time 1  # Time only
stream_set_format console --date 0 --time 0  # No timestamp

# Indentation
stream_set_format console --indent 5

# Suppress emojis
stream_set_format --suppress-emojis 1

# Different formats
stream_set_format console --date 0 --time 1
stream_set_format file --date 1 --time 1
```

### Default Message Feature

```bash
# Call without message - shows caller context
info
# Output: 2025-11-13 17:30:45 ℹ️  [INFO] - <No message> - main()#42 in script.sh
```

### Cleanup

```bash
# Clean up FDs at script exit
trap stream_cleanup EXIT

# Or manually
info "Last message"
stream_cleanup  # Closes FD3, FD4, etc.
```

## Performance

**Generated Function:**
```bash
# Enabled function:
info() { printf -- '%(%Y-%m-%d %H:%M:%S)T ℹ️  [INFO] - %s\n' -1 "${1:-...}" >&3; }

# Disabled function:
warn() { :; }  # literal no-op
```

**Characteristics:**
- Zero runtime conditionals (routing/formatting baked in at generation)
- Direct printf (no variable lookups)
- NOP functions are literal `:` (zero overhead)
- Config changes regenerate all functions (~0.002-0.003s)

**FD Management:**
- FD 1-2 (stdout, stderr) always available
- FD 3-9 automatically opened on first use (if needed)
- Tracked in registry, closed via `stream_cleanup()`
- FD outside 1-9 range causes error

## Tests

```bash
bash Test.sh

# Expected output:
╔════════════════════════════════════════════════════════════════════════════════╗
║                              TEST SUMMARY                                      ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  Total Tests:    17                                                            ║
║  Total Asserts:  57                                                            ║
║  ✓ Passed:       57                                                            ║
║  ✗ Failed:       0                                                             ║
╚════════════════════════════════════════════════════════════════════════════════╝
```

**Coverage:** All functions, channels, file output, formatting, NOP control, exit codes, special characters, default messages, FD management (validation, opening, cleanup).
