# Logger <!-- omit in toc -->

**Dynamic logging system with flexible logger creation**

Drop-in logging system with predefined loggers and dynamic logger creation. Supports file output, exit codes, emoji suppression, and intelligent default messages. Zero dependencies, pure Bash.

## Overview <!-- omit in toc -->

- **🎨 Dynamic logger creation** - Create custom loggers with `log_create_logger`
- **🚪 Exit code support** - Loggers can exit with custom codes (fatal, fail)
- **🧠 Smart default messages** - Auto-shows caller context when no message provided
- **⚙️ Argument-based configuration** - Set multiple options in one call
- **📝 File output** - Optional dual output to file + stderr
- **🔇 Emoji suppression** - Globally suppress emojis
- **🎯 Predefined loggers** - info, warn, error, fatal, pass, fail
- **📦 Minimal globals** - Single associative array for all config


     
## Table of Contents <!-- omit in toc -->
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Predefined Loggers](#predefined-loggers)
  - [Configuration](#configuration)
  - [Dynamic Logger Creation](#dynamic-logger-creation)
  - [File Management](#file-management)
  - [Utility Functions](#utility-functions)
- [Usage Examples](#usage-examples)
  - [Basic Logging](#basic-logging)
  - [File Output](#file-output)
  - [Customize Output Format](#customize-output-format)
  - [Dynamic Logger Creation](#dynamic-logger-creation-1)
  - [Emoji Suppression](#emoji-suppression)
  - [Custom Indentation](#custom-indentation)
  - [Default Message Feature](#default-message-feature)
  - [Exit Code Loggers](#exit-code-loggers)
- [Tests:](#tests)


## Requirements
- **Bash 4.0+** (for associative arrays)

## Quick Start

**Standard Usage:**
```bash
source logger.sh # All loggers predefined and ready to use

info "Application started"
warn "Configuration file missing, using defaults"
error "Failed to connect to database"
pass "All tests passed"
```



## API Reference

### Predefined Loggers

| Function | Icon | Tag | Exit Code | Usage |
|----------|------|-----|-----------|-------|
| `info [msg]` | ℹ️ | [INFO] | -1 (none) | General information |
| `warn [msg]` | ⚠️ | [WARN] | -1 (none) | Warnings, non-critical issues |
| `error [msg]` | ❌ | [ERROR] | -1 (none) | Error conditions |
| `fatal [msg]` | 💀 | [FATAL] | 1 | Critical errors (exits script) |
| `pass [msg]` | ✅ | [PASS] | -1 (none) | Successful operations |
| `fail [msg]` | ❌ | [FAIL] | 1 | Failed operations (exits script) |

**Note:** If no message is provided, loggers show caller context automatically.

### Configuration

**`log_set [options]`** - Configure multiple options at once

| Option | Description | Values |
|--------|-------------|--------|
| `--file PATH` | Set output file path (also: `--output`) | File path or empty to disable |
| `--timestamp BOOL` | Enable/disable timestamp | `1/0`, `true/false`, `on/off` |
| `--datestamp BOOL` | Enable/disable date in timestamp | `1/0`, `true/false`, `on/off` |
| `--indent NUMBER` | Set leading spaces | Number >= 0 (default: 1) |
| `--suppress-emojis BOOL` | Globally suppress emojis | `1/0`, `true/false`, `on/off` |

**Examples:**
```bash
# Single option
log_set --timestamp 0

# Multiple options at once
log_set --file "./logs/app.log" --timestamp 0 --indent 3

# Suppress all emojis globally
log_set --suppress-emojis 1
```

### Dynamic Logger Creation

**`log_create_logger <name> [options]`** - Create custom logger

| Option | Description | Default |
|--------|-------------|---------|
| `--emoji EMOJI` | Set emoji prefix | " 📝" |
| `--tag TAG` | Set tag prefix | " [name] -" |
| `--exit CODE` | Set exit code (-1 = no exit) | -1 |

**Example:**
```bash
log_create_logger "critical" --emoji " 🔥" --tag " [CRITICAL] -" --exit 99
critical "Database connection lost"  # Exits with code 99
```

### File Management

| Function | Description |
|----------|-------------|
| `log_get_file` | Get current log output file path |
| `log_show_file` | Display contents of current log file |
| `log_clear_file` | Clear log file content |

### Utility Functions

| Function | Description |
|----------|-------------|
| `console <msg>` | Plain output (no timestamp/prefix) |
| `consolef <fmt> [args...]` | Formatted output |
| `new_line` | Print newline to stderr |



## Usage Examples

### Basic Logging

```bash
source logger.sh

info "Starting backup process"
pass "Backed up 1523 files"
warn "Backup took longer than expected"
```

### File Output

```bash
source logger.sh

# Enable file logging
log_set --file "/var/log/myapp.log"

info "This goes to stderr AND /var/log/myapp.log"
error "Errors also logged to file"

# Disable file logging
log_set --file ""
```

### Customize Output Format

```bash
source logger.sh

# Set multiple options at once (efficient - only reinitializes once)
log_set --datestamp 0 --timestamp 1

info "Message with time only"
# Output:  15:30:45 ℹ️  [INFO] - Message with time only

# Disable timestamps completely
log_set --timestamp 0
info "Message without timestamp"
# Output:  ℹ️  [INFO] - Message without timestamp

```

### Dynamic Logger Creation

```bash
source logger.sh

# Create custom logger with specific exit code
log_create_logger "critical" --emoji " 🔥" --tag " [CRITICAL] -" --exit 99

# Use it like any other logger
critical "Database connection lost"  # Exits with code 99

# Create logger without exit (default)
log_create_logger "trace" --emoji " 🔍" --tag " [TRACE] -"
trace "Entering function: process_data()"
trace "Variable state: count=$count, status=$status"

# Create logger with default emoji/tag
log_create_logger "audit"
audit "User login: $username from $ip_address"
# Output:  2025-11-12 15:30:45 📝 [audit] - User login: admin from 192.168.1.100
```

### Emoji Suppression

```bash
source logger.sh

# Suppress all emojis globally
log_set --suppress-emojis 1

info "No emoji here"
# Output:  2025-11-12 15:30:45 [INFO] - No emoji here

warn "Still no emoji"
# Output:  2025-11-12 15:30:46 [WARN] - Still no emoji

# Re-enable emojis
log_set --suppress-emojis 0
info "Emoji restored"
# Output:  2025-11-12 15:30:47 ℹ️  [INFO] - Emoji restored
```

### Custom Indentation

```bash
source logger.sh

# Default has 1 space indent
info "Default indent"
#  2025-11-12 15:30:45 ℹ️  [INFO] - Default indent
# ^ one space

# No indent
log_set --indent 0
info "No indent"
# 2025-11-12 15:30:45 ℹ️  [INFO] - No indent

# Five spaces
log_set --indent 5
info "Five spaces"
#      2025-11-12 15:30:45 ℹ️  [INFO] - Five spaces
# ^^^^^ five spaces
```

### Default Message Feature

```bash
source logger.sh

# Call logger without message - shows caller info
info
# Output:  2025-11-12 15:30:45 ℹ️  [INFO] - <No message was passed> - called from main()#42 in myscript.sh

# With message
info "Processing data"
# Output:  2025-11-12 15:30:45 ℹ️  [INFO] - Processing data
```

### Exit Code Loggers

```bash
source logger.sh

# fatal and fail exit the script
validate_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        fatal "Config file not found: $CONFIG_FILE"  # Exits with code 1
        # Script stops here
    fi
}

run_tests() {
    if ! ./run_tests.sh; then
        fail "Test suite failed"  # Exits with code 1
        # Script stops here
    fi
    
    pass "All tests passed"  # Continues execution
}

# Custom exit codes with dynamic loggers
log_create_logger "abort" --emoji " ❌" --tag " [ABORT] -" --exit 42
abort "User cancelled operation"  # Exits with code 42
```



## Tests:
```bash
bash Test.sh

# Expected output:
...
╔════════════════════════════════════════════════════════════════════════════════╗
║                              TEST SUMMARY                                      ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  Total Tests:    11                                                            ║
║  Total Asserts:  35+                                                           ║
║  ✓ Passed:       35+                                                           ║
║  ✗ Failed:       0                                                             ║
╚════════════════════════════════════════════════════════════════════════════════╝
```
