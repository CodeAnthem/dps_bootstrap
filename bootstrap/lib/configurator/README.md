# Configurator v4.1

## Overview

The Configurator is a modular configuration system with auto-discovery, hook-based architecture, and dynamic visibility. It provides a clean separation between configuration data, validation logic, and presentation.

## Architecture

### Component Structure

```
configurator/
├── settingsLogic/          # Settings component
│   ├── logic_registry.sh   # Data registries and master lists
│   ├── settings.sh         # Settings API (create, validate, apply)
│   ├── logic_visibility.sh # Dynamic visibility evaluation
│   ├── logic_envImport.sh  # Environment variable import
│   └── logic_export.sh     # Configuration export
├── settingTypes/           # SettingTypes component
│   ├── settingTypes.sh     # Type registration and generic fallbacks
│   ├── text.sh             # Text input type
│   ├── toggle.sh           # Boolean toggle type
│   ├── choice.sh           # Multiple choice type
│   ├── diskSize.sh         # Disk size format type
│   ├── locale.sh           # Locale validation type
│   ├── country.sh          # Country with apply hook
│   └── ...
├── presetsLogic/           # Presets component
│   └── presets.sh          # Preset API (create, validate, display)
└── presets/                # Preset declarations
    ├── region.sh           # Regional settings
    ├── quick.sh            # Quick setup
    └── ...
```

### Key Principles

1. **Separation of Concerns**: Each component handles one responsibility
2. **Auto-Discovery**: SettingTypes and Presets auto-register themselves
3. **Hook-Based**: Extensible via function hooks (validate, normalize, apply, etc.)
4. **Performance**: Function pointers cached to avoid repeated lookups
5. **Consistent Naming**: `_type_verb` for settingTypes, `_preset_verb` for presets

## Core Concepts

### 1. SettingTypes

Reusable input types with validation, normalization, and display logic.

**Hooks (all optional except validate):**
- `_type_validate` - Validates input (required)
- `_type_normalize` - Normalizes value before storage
- `_type_errorCode` - Returns error message for invalid input
- `_type_promptHint` - Returns hint text for prompts
- `_type_display` - Transforms value for display
- `_type_apply` - Runs when value changes (side effects)
- `_type_prompt` - Custom prompt logic

**Example:**
```bash
_diskSize_promptHint() { echo "(e.g., 8G, 500M, 1T)"; }
_diskSize_validate() { [[ "$1" =~ ^[0-9]+[KMGT]?$ ]]; }
_diskSize_errorCode() { echo "Invalid disk size format"; }

nds_cfg_settingType_register "diskSize"
```

### 2. Settings

Individual configuration variables bound to a SettingType and Preset.

**Metadata:**
- `type` - SettingType to use for validation
- `preset` - Parent preset
- `display` - Human-readable name
- `default` - Default value
- `value` - Current value
- `origin` - Source of value (default, env, prompt, auto, manual)
- `exportable` - Whether to include in exports (default: true)
- `visible_all` - Visibility conditions (AND logic)
- `visible_any` - Visibility conditions (OR logic)
- `attr::*` - Type-specific attributes (e.g., options)

**Example:**
```bash
nds_cfg_setting_create HOSTNAME \
    --type hostname \
    --display "System Hostname" \
    --default "nixos"

nds_cfg_setting_create STATIC_IP \
    --type text \
    --display "Static IP Address" \
    --visible_all "NETWORK_MODE==static"
```

### 3. Presets

Logical groupings of settings with ordering and validation.

**Metadata:**
- `display` - Human-readable name
- `priority` - Sort order (lower = earlier)
- `order` - Space-separated list of settings
- `hook::validate` - Optional preset-level validation

**Example:**
```bash
nds_cfg_preset_create "region" \
    --display "Region" \
    --priority 50

nds_cfg_setting_create TIMEZONE \
    --type timezone \
    --display "Timezone" \
    --default "UTC"

nds_cfg_setting_create LOCALE \
    --type locale \
    --display "Primary Locale" \
    --default "en_US.UTF-8"

CFG_CONTEXT_PRESET=""
```

## Usage

### Initialization

```bash
# In main script
source lib/configurator.sh
nds_cfg_init
```

### Reading/Writing Values

```bash
# Get value
hostname=$(nds_cfg_get HOSTNAME)

# Set value (with validation)
nds_cfg_set HOSTNAME "myhost"

# Set value programmatically (with normalization, validation, apply hook)
nds_cfg_apply_setting HOSTNAME "myhost" "manual"
```

### Validation

```bash
# Validate single setting
if nds_cfg_setting_validate HOSTNAME; then
    echo "Valid"
fi

# Validate preset
if nds_cfg_preset_validate "region"; then
    echo "All region settings valid"
fi

# Validate all presets
nds_cfg_preset_validate
```

### Interactive Prompting

```bash
# Prompt for all visible settings in preset
nds_cfg_preset_prompt_all "region"

# Prompt only for invalid settings
nds_cfg_preset_prompt_errors "region"
```

### Display

```bash
# Display preset configuration
nds_cfg_preset_display "region" 1
```

### Export

```bash
# Export non-default values
nds_cfg_export_nonDefaults > config.sh

# Export all values
nds_cfg_export_all > config_full.sh
```

### Environment Import

```bash
# Import from NDS_* environment variables
export NDS_HOSTNAME="myhost"
export NDS_TIMEZONE="Europe/Berlin"
nds_cfg_env_import "NDS_"
```

### Queries

```bash
# Get all presets (sorted by priority)
nds_cfg_preset_getAllSorted

# Get all settings in preset
nds_cfg_preset_getSettings "region"

# Get visible settings only
nds_cfg_preset_getVisibleSettings "region"

# Check if setting exists
nds_cfg_setting_exists HOSTNAME

# Check visibility
if nds_cfg_setting_isVisible STATIC_IP; then
    echo "Visible"
fi
```

## Advanced Features

### Visibility Conditions

Settings can be conditionally visible based on other settings:

```bash
nds_cfg_setting_create STATIC_IP \
    --type text \
    --display "Static IP Address" \
    --visible_all "NETWORK_MODE==static"

nds_cfg_setting_create DISK_PASSWORD \
    --type secret \
    --display "Encryption Password" \
    --visible_all "DISK_ENCRYPT==true DISK_FORMAT!=btrfs"
```

**Operators:**
- `==` - equals
- `!=` - not equals  
- `<`, `>`, `<=`, `>=` - comparison (numeric if both numbers, else string)

**Logic:**
- `visible_all` - ALL conditions must be true (AND)
- `visible_any` - ANY condition must be true (OR)

### Apply Hooks

SettingTypes can define apply hooks that run when values change:

```bash
_country_apply() {
    local country="$1"
    
    # Automatically configure other settings
    case "${country,,}" in
        de)
            nds_cfg_apply_setting "TIMEZONE" "Europe/Berlin" "auto"
            nds_cfg_apply_setting "LOCALE" "de_DE.UTF-8" "auto"
            nds_cfg_apply_setting "KEYBOARD_LAYOUT" "de" "auto"
            ;;
        us)
            nds_cfg_apply_setting "TIMEZONE" "America/New_York" "auto"
            nds_cfg_apply_setting "LOCALE" "en_US.UTF-8" "auto"
            nds_cfg_apply_setting "KEYBOARD_LAYOUT" "us" "auto"
            ;;
    esac
}

nds_cfg_settingType_register "country"
```

Apply hooks run automatically on:
- User input via prompt
- Environment variable import
- Programmatic set via `nds_cfg_apply_setting`

### Origin Tracking

Every setting tracks its value source:

```bash
origin=$(nds_cfg_setting_get HOSTNAME "origin")
# Returns: default, env, prompt, auto, manual
```

This enables:
- Conflict resolution (env overrides default, prompt overrides env)
- Audit trails
- Selective export (e.g., only prompt-entered values)

### Type-Specific Attributes

Unknown flags are stored as attributes for type-specific use:

```bash
nds_cfg_setting_create BOOTLOADER \
    --type choice \
    --options "systemd-boot|grub|refind"

nds_cfg_setting_create DISK_SIZE \
    --type diskSize \
    --min "8G" \
    --max "500G"
```

Access via:
```bash
options="${CFG_SETTINGS["BOOTLOADER::attr::options"]}"
```

## Data Storage

All data is stored in associative arrays:

```bash
# Settings: VAR::field
CFG_SETTINGS["HOSTNAME::type"]="hostname"
CFG_SETTINGS["HOSTNAME::value"]="myhost"
CFG_SETTINGS["HOSTNAME::default"]="nixos"
CFG_SETTINGS["HOSTNAME::origin"]="prompt"
CFG_SETTINGS["HOSTNAME::hook::validate"]="_hostname_validate"

# Presets: preset::field
CFG_PRESETS["region::display"]="Region"
CFG_PRESETS["region::priority"]="50"
CFG_PRESETS["region::order"]="TIMEZONE LOCALE KEYBOARD_LAYOUT"

# SettingTypes: type::hook
CFG_SETTINGTYPES["hostname::validate"]="_hostname_validate"
CFG_SETTINGTYPES["hostname::normalize"]="_hostname_normalize"
```

Master lists:
```bash
CFG_ALL_SETTINGS=("HOSTNAME" "TIMEZONE" "LOCALE" ...)
CFG_ALL_PRESETS=("quick" "region" "network" ...)
CFG_ALL_SETTINGTYPES=("text" "toggle" "hostname" ...)
```

## Extending

### Adding a New SettingType

1. Create `lib/configurator/settingTypes/mytype.sh`
2. Implement hook functions (at minimum `_mytype_validate`)
3. Call `nds_cfg_settingType_register "mytype"`

### Adding a New Preset

1. Create `lib/configurator/presets/mypreset.sh`
2. Call `nds_cfg_preset_create` with metadata
3. Call `nds_cfg_setting_create` for each setting
4. Clear context: `CFG_CONTEXT_PRESET=""`

### Adding Preset Validation

Define a validation function with preset name prefix:

```bash
_network_validate() {
    local mode=$(nds_cfg_get NETWORK_MODE)
    local ip=$(nds_cfg_get NETWORK_IP)
    
    if [[ "$mode" == "static" && -z "$ip" ]]; then
        error "Static mode requires IP address"
        return 1
    fi
    
    return 0
}
```

Auto-detected if function `_<preset>_validate` exists.

## Testing

Run the test script:
```bash
cd bootstrap
bash lib/configurator/TEST_v4.1.sh
```

Or source it interactively:
```bash
source lib/configurator/TEST_v4.1.sh
nds_cfg_get HOSTNAME
nds_cfg_set HOSTNAME "test"
nds_cfg_export_nonDefaults
```

## Migration

See `MIGRATION_v4.1.md` for detailed migration guide from v3.x.

## API Reference

### Settings API

- `nds_cfg_setting_create VAR [--flags...]` - Create or modify setting
- `nds_cfg_setting_exists VAR` - Check if setting exists
- `nds_cfg_setting_validate VAR` - Validate current value
- `nds_cfg_setting_get VAR FIELD` - Get metadata field
- `nds_cfg_setting_set VAR FIELD VALUE` - Set metadata field
- `nds_cfg_setting_isVisible VAR` - Check visibility
- `nds_cfg_get VAR` - Get value
- `nds_cfg_set VAR VALUE` - Set value (validated)
- `nds_cfg_apply_setting VAR VALUE [ORIGIN]` - Set with full pipeline

### Presets API

- `nds_cfg_preset_create PRESET [--flags...]` - Create preset
- `nds_cfg_preset_exists PRESET` - Check if preset exists
- `nds_cfg_preset_validate PRESET` - Validate all settings
- `nds_cfg_preset_validate` - Validate all presets
- `nds_cfg_preset_get PRESET FIELD` - Get metadata
- `nds_cfg_preset_getSettings PRESET` - Get all settings
- `nds_cfg_preset_getVisibleSettings PRESET` - Get visible settings
- `nds_cfg_preset_getAllSorted` - Get all presets by priority
- `nds_cfg_preset_display PRESET [NUMBER]` - Display configuration
- `nds_cfg_preset_prompt_all PRESET` - Interactive prompt (all)
- `nds_cfg_preset_prompt_errors PRESET` - Interactive prompt (invalid only)

### SettingTypes API

- `nds_cfg_settingType_register TYPE` - Register type (auto-detect hooks)
- `nds_cfg_settingType_exists TYPE` - Check if type exists
- `nds_cfg_settingType_get TYPE HOOK` - Get hook function
- `nds_cfg_settingType_call TYPE HOOK [ARGS...]` - Execute hook

### Import/Export API

- `nds_cfg_env_import [PREFIX]` - Import from environment (default: NDS_)
- `nds_cfg_export_nonDefaults [PREFIX]` - Export non-default values
- `nds_cfg_export_all [PREFIX]` - Export all values

### Registry API

- `nds_cfg_setting_all` - List all settings
- `nds_cfg_preset_all` - List all presets
- `nds_cfg_registry_clearAll` - Clear all data (reset)

## Files

- `configurator.sh` - Master orchestrator
- `settingsLogic/logic_registry.sh` - Data registries
- `settingsLogic/settings.sh` - Settings operations
- `settingsLogic/logic_visibility.sh` - Visibility evaluation
- `settingsLogic/logic_envImport.sh` - Environment import
- `settingsLogic/logic_export.sh` - Configuration export
- `settingTypes/settingTypes.sh` - Type registration
- `settingTypes/*.sh` - Individual settingType implementations
- `presetsLogic/presets.sh` - Preset operations
- `presets/*.sh` - Preset declarations
- `MIGRATION_v4.1.md` - Migration guide from v3.x
- `README.md` - This file
- `TEST_v4.1.sh` - Test script
