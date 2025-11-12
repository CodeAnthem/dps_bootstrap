# Library Importer

**Safe library import with syntax validation and error aggregation**

Prevents script crashes from malformed libraries by validating syntax before sourcing. Supports single file import, recursive directory scanning, and named folder imports. Accumulates errors for batch reporting instead of failing fast. Pure Bash, zero dependencies.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Features](#features)
- [Public API Reference](#public-api-reference)
- [Usage Examples](#usage-examples)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Testing](#testing)
- [Requirements](#requirements)

---

## Quick Start

### Standard Bash Source (Unsafe)

```bash
#!/usr/bin/env bash

# Standard source - crashes on syntax errors
source /path/to/library.sh  # If this has errors, script dies
source /path/to/another.sh  # This never executes

echo "Script continues"  # Never reached
```

### With Library Importer (Safe)

```bash
#!/usr/bin/env bash
source libImporter.sh

# Safe import - validates syntax before sourcing
import_file /path/to/library.sh || {
    echo "Library failed to load, using fallback"
    # Graceful degradation
}

import_file /path/to/another.sh

echo "Script continues"  # Always reached
```

---

## Installation

```bash
# Source early in your script (before any library imports)
source libImporter.sh
```

**Optional: Custom Output Functions**

Override output functions after sourcing to customize logging:

```bash
source libImporter.sh

# Override output functions
debug() { [[ $DEBUG ]] && echo "[DBG] $*" >&2; }
error() { logger -t importer "[ERROR] $*"; }
```

---

## Features

| Feature | Description |
|---------|-------------|
| **Syntax Validation** | Validates Bash syntax before sourcing to prevent crashes |
| **Error Aggregation** | Collects multiple errors and reports them together |
| **Directory Import** | Import all `.sh` files from a directory |
| **Recursive Scanning** | Optionally recurse into subdirectories |
| **Named Import** | Import file matching parent folder name |
| **Underscore Filtering** | Automatically skips `_`-prefixed files/folders |
| **Validation Only** | Check syntax without sourcing |
| **Zero Dependencies** | Pure Bash, no external tools required |

---

## Public API Reference

### File Import Functions

| Function | Description |
|----------|-------------|
| `import_file <filepath>` | Import and validate a single file |
| `import_dir <directory> [recursive]` | Import all `.sh` files from directory |
| `import_named <folder_path>` | Import file named after parent folder |
| `import_validate <filepath>` | Validate syntax only (no source) |

### Function Details

#### import_file

```bash
import_file <filepath>
```

**Parameters:**
- `filepath` - Path to the file to import

**Returns:**
- `0` - File imported successfully
- `1` - File not found or validation/source failed

**Example:**
```bash
import_file /path/to/library.sh || echo "Import failed"
```

#### import_dir

```bash
import_dir <directory> [recursive]
```

**Parameters:**
- `directory` - Path to directory to scan
- `recursive` - Optional: `true` for recursive, `false` for single level (default: `false`)

**Returns:**
- `0` - All files imported successfully
- `1` - One or more files failed

**Example:**
```bash
import_dir /path/to/libs false      # Single level
import_dir /path/to/libs true       # Recursive
```

**Notes:**
- Only imports `*.sh` files
- Skips files/folders starting with `_` (underscore)
- Errors are accumulated and displayed together

#### import_named

```bash
import_named <folder_path>
```

**Parameters:**
- `folder_path` - Path to folder containing the named file

**Returns:**
- `0` - File imported successfully
- `1` - Folder not found or named file missing

**Example:**
```bash
import_named /path/to/mymodule
# Imports: /path/to/mymodule/mymodule.sh
```

**Use Case:** Organize modules where folder name matches file name for clean imports.

#### import_validate

```bash
import_validate <filepath>
```

**Parameters:**
- `filepath` - Path to file to validate

**Returns:**
- `0` - Syntax is valid
- `1` - Syntax errors found

**Example:**
```bash
if import_validate /path/to/script.sh; then
    echo "Syntax OK"
else
    echo "Syntax errors found"
fi
```

---

## Usage Examples

### Example 1: Import Single File with Error Handling

```bash
#!/usr/bin/env bash
source libImporter.sh

if import_file /opt/myapp/config.sh; then
    echo "Configuration loaded successfully"
else
    echo "Failed to load configuration, using defaults"
    # Set default values
    CONFIG_MODE="default"
fi
```

### Example 2: Import All Libraries from Directory

```bash
#!/usr/bin/env bash
source libImporter.sh

# Import all .sh files from lib directory (non-recursive)
if import_dir /opt/myapp/lib false; then
    echo "All libraries loaded"
else
    echo "Some libraries failed to load"
    exit 1
fi
```

### Example 3: Recursive Directory Import

```bash
#!/usr/bin/env bash
source libImporter.sh

# Import all .sh files recursively
import_dir /opt/myapp/modules true || {
    echo "Error loading modules"
    exit 1
}

# All modules loaded, start application
main
```

### Example 4: Named Module Import

```bash
#!/usr/bin/env bash
source libImporter.sh

# Project structure:
#   /opt/myapp/
#     ├── database/
#     │   └── database.sh
#     ├── logging/
#     │   └── logging.sh
#     └── utils/
#         └── utils.sh

import_named /opt/myapp/database
import_named /opt/myapp/logging
import_named /opt/myapp/utils

# Now use functions from imported modules
db_connect
log_info "Application started"
```

### Example 5: Validate Before Import (Pre-flight Check)

```bash
#!/usr/bin/env bash
source libImporter.sh

# Validate all libraries before importing any
LIBS=(
    /opt/myapp/core.sh
    /opt/myapp/plugins.sh
    /opt/myapp/handlers.sh
)

echo "Validating libraries..."
for lib in "${LIBS[@]}"; do
    if ! import_validate "$lib"; then
        echo "Validation failed: $lib"
        exit 1
    fi
done

echo "All libraries validated, importing..."
for lib in "${LIBS[@]}"; do
    import_file "$lib"
done
```

### Example 6: Conditional Import with Fallback

```bash
#!/usr/bin/env bash
source libImporter.sh

# Try to load optional enhanced module
if import_file /opt/myapp/enhanced_features.sh 2>/dev/null; then
    echo "Enhanced features enabled"
    use_enhanced_mode=true
else
    echo "Using standard features"
    use_enhanced_mode=false
fi
```

---

## Error Handling

### Error Types

1. **File Not Found**
   ```bash
   $ import_file /nonexistent/file.sh
   [ERROR] File not found: /nonexistent/file.sh
   ```

2. **Validation Error (Syntax)**
   ```bash
   $ import_file /path/to/bad_syntax.sh
   [Validation Error] /path/to/bad_syntax.sh:
    -> line 5: unexpected EOF while looking for matching `"'
    -> line 10: syntax error: unexpected end of file
   ```

3. **Source Error**
   ```bash
   [Source Error] /path/to/file.sh
   ```

### Error Aggregation

When importing directories, errors are accumulated and displayed together:

```bash
$ import_dir /opt/myapp/libs false

[Validation Error] /opt/myapp/libs/broken.sh:
 -> line 3: unexpected EOF

[Source Error] /opt/myapp/libs/fails.sh
```

### Checking for Errors

```bash
# Method 1: Check exit code
import_dir /path/to/libs false
if [[ $? -ne 0 ]]; then
    echo "Import failed"
fi

# Method 2: Use in conditional
if import_dir /path/to/libs false; then
    echo "Success"
else
    echo "Failed"
fi

# Method 3: Inline with ||
import_dir /path/to/libs false || exit 1
```

---

## Best Practices

### 1. Import Early

Source the importer early, before any library imports:

```bash
#!/usr/bin/env bash
# First thing after shebang
source libImporter.sh

# Then import your libraries
import_dir /opt/myapp/lib false
```

### 2. Use Named Imports for Modules

Organize code with named folders for cleaner imports:

```
myapp/
├── config/
│   └── config.sh       # Configuration module
├── logging/
│   └── logging.sh      # Logging module
└── database/
    └── database.sh     # Database module
```

```bash
import_named /opt/myapp/config
import_named /opt/myapp/logging
import_named /opt/myapp/database
```

### 3. Validate Critical Libraries First

For mission-critical scripts, validate before importing:

```bash
# Validate all critical libraries first
for lib in "${CRITICAL_LIBS[@]}"; do
    import_validate "$lib" || {
        echo "Critical library failed validation: $lib"
        exit 1
    }
done

# All validated, now import
for lib in "${CRITICAL_LIBS[@]}"; do
    import_file "$lib"
done
```

### 4. Skip Internal Files with Underscore

Use underscore prefix for internal/test files that shouldn't be auto-imported:

```
libs/
├── public_api.sh       # Imported
├── utilities.sh        # Imported
├── _internal.sh        # Skipped (underscore prefix)
└── _test_helpers.sh    # Skipped (underscore prefix)
```

### 5. Handle Import Failures Gracefully

Don't let import failures crash your script:

```bash
import_file /opt/plugins/optional.sh 2>/dev/null || {
    warn "Optional plugin not available, using defaults"
    use_defaults=true
}
```

### 6. Group Related Imports

Organize imports logically:

```bash
# Core libraries (required)
import_file /opt/myapp/core/init.sh || exit 1
import_file /opt/myapp/core/config.sh || exit 1

# Utilities (required)
import_dir /opt/myapp/utils false || exit 1

# Plugins (optional)
import_dir /opt/myapp/plugins false 2>/dev/null
```

---

## Testing

Run the test suite to verify functionality:

```bash
bash libImporter_test.sh
```

All **11 tests** (33 assertions) should pass. Tests cover:
- Valid file import
- Nonexistent file handling
- Syntax error detection
- Directory import (recursive and non-recursive)
- Underscore-prefixed file filtering
- Named folder import
- Validation-only mode
- Error accumulation
- Invalid parameter handling

---

## Requirements

- **Bash 3.2+** (no special features required)
- **Pure Bash** - no external dependencies

---

## Comparison: Standard vs Library Importer

| Scenario | Standard `source` | Library Importer |
|----------|-------------------|------------------|
| **File not found** | Script crashes | Returns error, script continues |
| **Syntax error** | Script crashes | Validates first, returns error |
| **Multiple files** | Stops at first error | Validates all, reports all errors |
| **Directory import** | Manual loop required | Built-in with `import_dir` |
| **Recursive import** | Complex manual code | Single parameter: `true` |
| **Error handling** | Try-catch patterns needed | Clean exit codes and messages |
| **Debugging** | Cryptic bash errors | Clear validation messages |

---

## Advanced Usage

### Import with Debug Output

```bash
# Enable debug output
debug() { echo "[DEBUG] $*" >&2; }

source libImporter.sh

# Now you'll see debug messages
import_dir /opt/myapp/libs false
# [DEBUG] Validating and sourcing: /opt/myapp/libs/core.sh
# [DEBUG] Successfully sourced: /opt/myapp/libs/core.sh
```

### Custom Error Handling

```bash
# Override error function for custom logging
error() {
    logger -t myapp "[ERROR] $*"
    echo "[ERROR] $*" >&2
}

source libImporter.sh

# Errors now logged to syslog and stderr
import_file /bad/file.sh
```

### Combining Validation and Import

```bash
#!/usr/bin/env bash
source libImporter.sh

validate_and_import() {
    local file="$1"
    
    echo "Validating: $file"
    if ! import_validate "$file"; then
        return 1
    fi
    
    echo "Importing: $file"
    import_file "$file"
}

validate_and_import /path/to/library.sh || exit 1
```

---

## License

Part of DPS Bootstrap - NixOS Deployment System
