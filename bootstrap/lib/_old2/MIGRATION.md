# Migration Summary - Input System Refactor

## What Changed

Refactored scattered validation and prompt functions into a **three-layer architecture**:
- **Units** - Specialized types with custom behavior
- **Types** - Generic reusable prompts  
- **Validation** - Standalone validator functions

---

## File Moves

### Old Structure (Moved to `_old/`)
```
bootstrap/lib/
├── inputHelpers.sh              → _old/inputHelpers.sh
└── inputValidation/             → _old/inputValidation/
    ├── validation_network.sh
    ├── validation_common.sh
    ├── validation_choice.sh
    └── validation_timezone.sh
```

### New Structure
```
bootstrap/lib/input/
├── units/
│   ├── disk.sh                  # NEW: disk selection with listing
│   └── timezone.sh              # MIGRATED: from validation_timezone.sh
├── types/
│   ├── text.sh                  # MIGRATED: prompt_validated from inputHelpers.sh
│   ├── bool.sh                  # MIGRATED: prompt_bool from inputHelpers.sh
│   ├── choice.sh                # MIGRATED: prompt_choice + validate_choice
│   └── number.sh                # MIGRATED: prompt_number from inputHelpers.sh
└── validation/
    ├── network.sh               # MIGRATED: from validation_network.sh
    ├── system.sh                # NEW: username, URL, path validators
    └── common.sh                # MIGRATED: from validation_common.sh
```

---

## Function Migration Map

### From `_old/inputHelpers.sh`
| Old Function | New Location | Notes |
|--------------|--------------|-------|
| `prompt_validated()` | `input/types/text.sh` | Generic text prompt |
| `prompt_bool()` | `input/types/bool.sh` | Boolean y/n prompt |
| `prompt_choice()` | `input/types/choice.sh` | Multiple choice prompt |
| `prompt_number()` | `input/types/number.sh` | Numeric input prompt |
| `prompt_disk()` | `input/units/disk.sh` | Moved to disk unit |
| `list_available_disks()` | `input/units/disk.sh` | Moved to disk unit |

### From `_old/inputValidation/validation_network.sh`
| Old Function | New Location | Notes |
|--------------|--------------|-------|
| `validate_ip()` | `input/validation/network.sh` | ✓ |
| `validate_hostname()` | `input/validation/network.sh` | ✓ |
| `validate_netmask()` | `input/validation/network.sh` | ✓ |
| `validate_port()` | `input/validation/network.sh` | ✓ |
| `validate_subnet()` | `input/validation/network.sh` | ✓ |
| `cidr_to_netmask()` | `input/validation/network.sh` | Helper function |
| `ip_to_int()` | `input/validation/network.sh` | Helper function |

### From `_old/inputValidation/validation_common.sh`
| Old Function | New Location | Notes |
|--------------|--------------|-------|
| `validate_nonempty()` | `input/validation/common.sh` | ✓ |
| `validate_username()` | `input/validation/system.sh` | Moved to system validators |
| `validate_timezone()` | `input/units/timezone.sh` | Moved to timezone unit |
| `validate_disk_size()` | `input/validation/common.sh` | ✓ |

### From `_old/inputValidation/validation_choice.sh`
| Old Function | New Location | Notes |
|--------------|--------------|-------|
| `validate_choice()` | `input/types/choice.sh` | Co-located with prompt |

### From `_old/inputValidation/validation_timezone.sh`
| Old Function | New Location | Notes |
|--------------|--------------|-------|
| `validate_timezone()` | `input/units/timezone.sh` | Now a unit |

### New Functions (Created During Migration)
| Function | Location | Purpose |
|----------|----------|---------|
| `validate_url()` | `input/validation/system.sh` | URL format validation |
| `validate_path()` | `input/validation/system.sh` | Path format validation |
| `validate_file_path()` | `input/validation/system.sh` | File existence check |
| `validate_dir_path()` | `input/validation/system.sh` | Directory existence check |
| `validate_number()` | `input/types/number.sh` | Generic number validation |
| `validate_disk_path()` | `input/units/disk.sh` | Block device validation |

---

## Config Module Updates

### `setupConfiguration/disk.sh`
```bash
# BEFORE
field_declare DISK_TARGET \
    type=disk \
    validator=validate_disk_path

# AFTER
field_declare DISK_TARGET \
    unit=disk                    # ← Now uses unit system
```

### `setupConfiguration/custom.sh`
```bash
# BEFORE
field_declare TIMEZONE \
    type=text \
    validator=validate_timezone

# AFTER
field_declare TIMEZONE \
    unit=timezone                # ← Now uses unit system
```

### Other Fields (No Change)
```bash
# These stay the same - using type + validator pattern
field_declare IP_ADDRESS type=text validator=validate_ip
field_declare HOSTNAME type=text validator=validate_hostname
field_declare ENCRYPTION type=bool
field_declare NETWORK_METHOD type=choice options="dhcp|static"
```

---

## Core System Updates

### `setupConfiguration.sh`
**Added:**
- `load_input_unit()` - Lazy-load unit files on demand
- Unit-based dispatch in `field_prompt()`
- Priority system: unit → type → default

**Changed:**
- `field_prompt()` now checks for `unit=xxx` attribute first
- Falls back to `type=xxx` if no unit specified
- Loads unit files dynamically when needed

**Removed:**
- Direct references to old `inputHelpers.sh` functions (now auto-loaded)

---

## Loading Mechanism

### Before
```bash
# All functions loaded from single files
source lib/inputHelpers.sh
source lib/inputValidation/*.sh
```

### After
```bash
# Automatic recursive loading by main.sh
source_lib_recursive "$LIB_DIR"

# Lazy loading of units when needed
if [[ -n "$unit" ]]; then
    load_input_unit "$unit"
fi
```

---

## Benefits Achieved

### ✅ Co-location
- Disk prompt + validator + helpers in `units/disk.sh`
- Timezone validator in `units/timezone.sh`
- Choice prompt + validator in `types/choice.sh`

### ✅ Reusability
- `validate_ip()` used by 4+ fields (IP, gateway, DNS)
- No duplication - single source of truth

### ✅ Extensibility  
- Add new unit: Create `units/myunit.sh` with validate + prompt
- Add new validator: Add function to `validation/*.sh`
- No core system changes needed

### ✅ Clarity
- Clear file structure: units/ types/ validation/
- Easy to find: "Where's the IP validator?" → `validation/network.sh`

---

## Testing Checklist

After migration, test:
- [ ] Disk selection prompts with numbered list
- [ ] Timezone input accepts valid timezones
- [ ] IP address validation (used in 4 fields)
- [ ] Boolean prompts (y/n)
- [ ] Choice prompts (dhcp|static)
- [ ] Number prompts (SSH port)
- [ ] Text prompts with custom validators

---

## Rollback

If issues arise:
```bash
# Restore old files
mv lib/_old/inputHelpers.sh lib/
mv lib/_old/inputValidation lib/

# Remove new structure
rm -rf lib/input/

# Revert config modules
git checkout lib/setupConfiguration/disk.sh
git checkout lib/setupConfiguration/custom.sh
```
