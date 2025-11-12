# Library Importer

**Safe library import with syntax validation and error aggregation**

Validates Bash syntax before sourcing to prevent crashes. Supports single files, directories (recursive), and named folder imports. Pure Bash, zero dependencies.

---

## Quick Start

```bash
# Standard source (unsafe)
source /path/to/lib.sh  # Crashes on syntax errors

# With importer (safe)
source libImporter.sh
import_file /path/to/lib.sh || echo "Import failed, using fallback"
```

---

## API Reference

| Function | Description |
|----------|-------------|
| `import_file <filepath>` | Import single file with validation |
| `import_dir <dir> [recursive]` | Import all `.sh` files (recursive: `true\|false`) |
| `import_named <folder>` | Import file matching folder name |
| `import_validate <filepath>` | Validate syntax only (no source) |

---

## Usage Examples

### Import Single File

```bash
source libImporter.sh

import_file /opt/myapp/config.sh || {
    echo "Config failed, using defaults"
    CONFIG_MODE="default"
}
```

### Import Directory

```bash
source libImporter.sh

# Non-recursive (single level)
import_dir /opt/myapp/lib false

# Recursive (all subdirectories)
import_dir /opt/myapp/modules true
```

### Named Import

```bash
source libImporter.sh

# Project structure:
#   /opt/myapp/database/database.sh
#   /opt/myapp/logging/logging.sh

import_named /opt/myapp/database  # Sources database/database.sh
import_named /opt/myapp/logging   # Sources logging/logging.sh
```

### Validate Before Import

```bash
source libImporter.sh

# Pre-flight check
for lib in "${LIBS[@]}"; do
    import_validate "$lib" || exit 1
done

# All valid, now import
for lib in "${LIBS[@]}"; do
    import_file "$lib"
done
```

---

## Features

- **Syntax Validation** - Checks syntax before sourcing
- **Error Aggregation** - Collects multiple errors, reports together
- **Directory Import** - Import all `.sh` files from directory
- **Recursive Scanning** - Optional subdirectory recursion
- **Named Import** - Import file matching parent folder name
- **Underscore Filtering** - Skips `_`-prefixed files/folders
- **Validation Only** - Check syntax without sourcing

---

## Error Handling

### Error Types

```bash
# File not found
$ import_file /nonexistent.sh
[ERROR] File not found: /nonexistent.sh

# Syntax error
$ import_file /bad_syntax.sh
[Validation Error] /bad_syntax.sh:
 -> line 5: unexpected EOF while looking for matching `"'
 -> line 10: syntax error: unexpected end of file

# Directory with multiple errors (accumulated)
$ import_dir /opt/libs false
[Validation Error] /opt/libs/broken.sh:
 -> line 3: unexpected EOF
[Source Error] /opt/libs/fails.sh
```

### Check Return Codes

```bash
# Method 1: Check exit code
import_dir /path/libs false
[[ $? -eq 0 ]] && echo "Success" || echo "Failed"

# Method 2: Conditional
if import_file /path/lib.sh; then
    echo "Loaded"
else
    echo "Failed"
fi

# Method 3: Inline
import_dir /path/libs false || exit 1
```

---

## Best Practices

### 1. Import Early

```bash
#!/usr/bin/env bash
source libImporter.sh  # First thing

import_dir /opt/myapp/lib false
```

### 2. Use Named Imports for Modules

```
myapp/
├── config/config.sh
├── logging/logging.sh
└── database/database.sh
```

```bash
import_named /opt/myapp/config
import_named /opt/myapp/logging
import_named /opt/myapp/database
```

### 3. Skip Internal Files with Underscore

```
libs/
├── api.sh           # Imported
├── utils.sh         # Imported
├── _internal.sh     # Skipped
└── _test.sh         # Skipped
```

### 4. Handle Failures Gracefully

```bash
import_file /opt/plugins/optional.sh 2>/dev/null || {
    warn "Optional plugin unavailable"
    use_defaults=true
}
```

### 5. Validate Critical Libraries First

```bash
# Validate all first
for lib in "${CRITICAL_LIBS[@]}"; do
    import_validate "$lib" || exit 1
done

# Then import
for lib in "${CRITICAL_LIBS[@]}"; do
    import_file "$lib"
done
```

---

## Testing

Run test suite:

```bash
bash libImporter_test.sh
```

**11 tests, 33 assertions** covering all functionality.

---

## Requirements

- **Bash 3.2+**
- **Pure Bash** - no external dependencies

---

## License

Part of DPS Bootstrap - NixOS Deployment System
