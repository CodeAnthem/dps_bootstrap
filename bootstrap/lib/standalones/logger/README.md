# Logger

**Timestamped logging with multiple levels and optional file output**

Production-ready logging with info/warn/error/fatal/success levels. Supports file output, custom timestamps, and flexible configuration. Zero dependencies, pure Bash.

---

## Quick Start

```bash
source logger.sh

info "Application started"
warn "Configuration file missing, using defaults"
error "Failed to connect to database"
success "Deployment completed"
```

---

## API Reference

### Logging Functions

| Function | Level | Icon | Usage |
|----------|-------|------|-------|
| `info <msg>` | Info | ℹ️ | General information |
| `warn <msg>` | Warning | ⚠️ | Warnings, non-critical issues |
| `error <msg>` | Error | ❌ | Error conditions |
| `fatal <msg>` | Fatal | ❌ | Critical errors (doesn't exit) |
| `success <msg>` | Success | ✅ | Successful operations |
| `validation_error <msg>` | Validation | ❌ | Input validation errors |

### Utility Functions

| Function | Description |
|----------|-------------|
| `console <msg>` | Plain output (no timestamp/prefix) |
| `consolef <fmt> [args]` | Formatted output |
| `new_line` | Print newline to stderr |

### Configuration Functions

| Function | Description |
|----------|-------------|
| `log_init` | Reinitialize all logging functions (called automatically after config changes) |
| `log_set_output_file <path>` | Enable file logging (empty=disable) |
| `log_get_output_file` | Get current log file path |
| `log_set_timestamp <1\|0>` | Enable/disable timestamps |
| `log_set_datestamp <1\|0>` | Enable/disable date in timestamp (time only if off) |
| `log_set_stream <stderr\|stdout>` | Set output stream |
| `log_set_emoji <level> <emoji>` | Set emoji for level (info/warn/error/fatal/success/validation) |
| `log_set_tag <level> <tag>` | Set tag for level |
| `log_clear_file` | Clear log file content |

---

## Usage Examples

### Basic Logging

```bash
source logger.sh

info "Starting backup process"
success "Backed up 1523 files"
warn "Backup took longer than expected"
```

### File Output

```bash
source logger.sh

# Enable file logging
log_set_output_file "/var/log/myapp.log"

info "This goes to stderr AND /var/log/myapp.log"
error "Errors also logged to file"

# Disable file logging
log_set_output_file ""
```

### Customize Output Format

```bash
source logger.sh

# Show time only (no date)
log_set_datestamp 0
info "Message with time only"
# Output:  15:30:45 ℹ️  [INFO] - Message with time only

# Disable timestamps completely
log_set_timestamp 0
info "Message without timestamp"
# Output:  ℹ️  [INFO] - Message without timestamp

# Customize emoji and tag for a specific level
log_set_emoji info " 📝"
log_set_tag info " [LOG] -"
info "Custom formatted message"
# Output:  2025-11-12 15:30:45 📝 [LOG] - Custom formatted message

# Remove emoji completely
log_set_emoji info ""
info "No emoji message"
```

### Application Logging

```bash
#!/usr/bin/env bash
source logger.sh

# Configure logging
LOG_DIR="/var/log/myapp"
mkdir -p "$LOG_DIR"
log_set_output_file "$LOG_DIR/myapp-$(date +%Y%m%d).log"

info "Application started"

# Process files
for file in *.txt; do
    if process_file "$file"; then
        success "Processed: $file"
    else
        error "Failed to process: $file"
    fi
done

info "Application finished"
```

### Validation Messages

```bash
source logger.sh

validate_input() {
    local input="$1"
    
    if [[ -z "$input" ]]; then
        validation_error "Input cannot be empty"
        return 1
    fi
    
    if [[ ! "$input" =~ ^[0-9]+$ ]]; then
        validation_error "Input must be numeric"
        return 1
    fi
    
    return 0
}

if validate_input "$USER_INPUT"; then
    success "Validation passed"
else
    error "Validation failed"
fi
```

### Plain Console Output

```bash
source logger.sh

# Plain output (no timestamp, no prefix)
console "========================================="
console "        My Application v1.0"
console "========================================="
new_line

# Then use regular logging
info "Starting up..."

# Formatted console output
consolef "Processing %d files..." "$file_count"
```

---

## Output Format

### With Timestamps (default)

```
 2025-11-12 15:30:45 ℹ️  [INFO] - Application started
 2025-11-12 15:30:46 ⚠️  [WARN] - Cache miss
 2025-11-12 15:30:47 ✅ [SUCCESS] - Task completed
 2025-11-12 15:30:48 ❌ [ERROR] - Connection failed
```

### Without Timestamps

```
 ℹ️  [INFO] - Application started
 ⚠️  [WARN] - Cache miss
 ✅ [SUCCESS] - Task completed
 ❌ [ERROR] - Connection failed
```

---

## Configuration

### Configuration Options

| Setting | Function | Default |
|---------|----------|---------|
| Output file | `log_set_output_file` | `""` (disabled) |
| Timestamp | `log_set_timestamp` | `1` (enabled) |
| Datestamp | `log_set_datestamp` | `1` (show date) |
| Output stream | `log_set_stream` | `stderr` |
| Emoji (per level) | `log_set_emoji` | See defaults below |
| Tag (per level) | `log_set_tag` | See defaults below |

**Default Emojis and Tags:**
- **info**: ` ℹ️ ` / ` [INFO] -`
- **warn**: ` ⚠️ ` / ` [WARN] -`
- **error**: ` ❌` / ` [ERROR] -`
- **fatal**: ` ❌` / ` [FATAL] -`
- **success**: ` ✅` / ` [SUCCESS] -`
- **validation**: ` ❌` / ` [VALIDATION] -`

### Performance Optimization

The logger uses **dynamic function generation** - all logging functions are rebuilt when settings change:

- **Zero format overhead** - output format is pre-built into each function
- **No repeated checks** - timestamp/file logic baked into function body
- **Per-level customization** - each level gets its own optimized function
- **File output baked in** - file writes included only when configured

This means minimal performance impact even in high-throughput logging scenarios.

---

## Best Practices

### 1. Configure Early

```bash
source logger.sh

# Set up logging first
log_set_output_file "/var/log/myapp.log"
log_set_datestamp 0  # Time only

# Then start logging
info "Logger configured"
```

### 2. Use Appropriate Levels

- `info` - Normal operation milestones
- `success` - Successful completions
- `warn` - Issues that don't stop execution
- `error` - Errors that affect functionality
- `fatal` - Critical errors (but doesn't exit automatically)
- `validation_error` - Input validation failures

### 3. Structured Logging

```bash
# Good: Context-rich messages
info "Processing file: $filename (size: $filesize bytes)"
error "Database connection failed (host: $DB_HOST, timeout: ${TIMEOUT}s)"

# Avoid: Vague messages
info "Processing"
error "Failed"
```

### 4. Log Rotation

```bash
# Daily log files
DATE=$(date +%Y%m%d)
log_set_output_file "/var/log/myapp-${DATE}.log"

# Or use logrotate for automatic rotation
```

---

## Requirements

- **Bash 3.2+** (widely compatible)
- **Pure Bash** - no external dependencies

---

## License

Part of DPS Bootstrap - NixOS Deployment System
