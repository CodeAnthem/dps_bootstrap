# Configurator v4.1 Migration Guide

## Overview

The configurator has been completely refactored to v4.1 architecture with a cleaner, more modular structure. This guide explains the changes and how to migrate.

## What Changed

### Project Structure

**Old (v3.x):**
```
lib/
├── configurator.sh
└── config/
    ├── storage.sh
    ├── var.sh
    ├── preset.sh
    ├── menu.sh
    ├── inputs/           # Input validators
    └── presets/          # Preset definitions
```

**New (v4.1):**
```
lib/
├── configurator.sh       # Master orchestrator
└── configurator/
    ├── settingsLogic/
    │   ├── logic_registry.sh      # Data registries
    │   ├── settings.sh            # Settings API
    │   ├── logic_visibility.sh    # Visibility evaluation
    │   ├── logic_envImport.sh     # Env import
    │   └── logic_export.sh        # Export
    ├── settingTypes/
    │   ├── settingTypes.sh        # Type registration
    │   ├── text.sh
    │   ├── toggle.sh
    │   ├── choice.sh
    │   ├── diskSize.sh
    │   ├── locale.sh
    │   ├── country.sh
    │   └── ...
    ├── presetsLogic/
    │   └── presets.sh             # Preset API
    └── presets/
        ├── region.sh
        ├── quick.sh
        └── ...
```

### Naming Conventions

#### Function Names

| Old Pattern | New Pattern | Example |
|------------|-------------|---------|
| `validate_<type>` | `_<type>_validate` | `_diskSize_validate` |
| `normalize_<type>` | `_<type>_normalize` | `_locale_normalize` |
| `display_<type>` | `_<type>_display` | `_toggle_display` |
| `error_msg_<type>` | `_<type>_errorCode` | `_diskSize_errorCode` |
| `prompt_hint_<type>` | `_<type>_promptHint` | `_locale_promptHint` |
| `<preset>_init` | Embedded in preset file | (no function) |
| `<preset>_validate_extra` | `_<preset>_validate` | `_region_validate` |

#### Array Keys

| Old Pattern | New Pattern | Example |
|------------|-------------|---------|
| `VAR_META["VAR__field"]` | `CFG_SETTINGS["VAR::field"]` | `CFG_SETTINGS["HOSTNAME::type"]` |
| `PRESET_META["preset__field"]` | `CFG_PRESETS["preset::field"]` | `CFG_PRESETS["region::priority"]` |
| `CONFIG_DATA["VAR"]` | `CFG_SETTINGS["VAR::value"]` | `CFG_SETTINGS["HOSTNAME::value"]` |
| (N/A) | `CFG_SETTINGTYPES["type::hook"]` | `CFG_SETTINGTYPES["diskSize::validate"]` |

#### API Functions

| Old Function | New Function | Notes |
|-------------|--------------|-------|
| `nds_configurator_var_declare` | `nds_cfg_setting_create` | Uses `--flag value` syntax |
| `nds_configurator_config_get` | `nds_cfg_get` | Simpler name |
| `nds_configurator_config_set` | `nds_cfg_set` | Simpler name |
| `nds_configurator_preset_validate` | `nds_cfg_preset_validate` | Same functionality |
| `nds_configurator_init` | `nds_cfg_init` | Also available for backward compat |

## How to Migrate

### 1. Migrating SettingTypes (Input Validators)

**Old (`lib/config/inputs/primitive/toggle.sh`):**
```bash
prompt_hint_toggle() {
    echo "(true/false, enabled/disabled)"
}

validate_toggle() {
    local value="$1"
    [[ "${value,,}" =~ ^(true|false|enabled|disabled|1|0)$ ]]
}

normalize_toggle() {
    local value="$1"
    case "${value,,}" in
        true|enabled|1) echo "true" ;;
        false|disabled|0) echo "false" ;;
    esac
}

display_toggle() {
    local value="$1"
    case "$value" in
        true) echo "✓" ;;
        false) echo "✗" ;;
    esac
}

error_msg_toggle() {
    echo "Enter true, false, enabled, or disabled"
}
```

**New (`lib/configurator/settingTypes/toggle.sh`):**
```bash
_toggle_promptHint() {
    echo "(true/false, enabled/disabled)"
}

_toggle_validate() {
    local value="$1"
    [[ "${value,,}" =~ ^(true|false|enabled|disabled|1|0)$ ]]
}

_toggle_normalize() {
    local value="$1"
    case "${value,,}" in
        true|enabled|1) echo "true" ;;
        false|disabled|0) echo "false" ;;
    esac
}

_toggle_display() {
    local value="$1"
    case "$value" in
        true) echo "✓" ;;
        false) echo "✗" ;;
    esac
}

_toggle_errorCode() {
    echo "Enter true, false, enabled, or disabled"
}

# Auto-register this settingType
nds_cfg_settingType_register "toggle"
```

**Changes:**
- Rename functions: `validate_` → `_type_validate`
- Rename `error_msg_` → `_type_errorCode`
- Add registration call at end

### 2. Migrating Presets

**Old (`lib/config/presets/region.sh`):**
```bash
region_init() {
    nds_configurator_preset_set_display "region" "Region"
    nds_configurator_preset_set_priority "region" 50
    
    nds_configurator_var_declare TIMEZONE \
        display="Timezone" \
        input=timezone \
        required=true \
        default="UTC"
    
    nds_configurator_var_declare LOCALE_MAIN \
        display="Primary Locale" \
        input=locale \
        required=true \
        default="en_US.UTF-8"
}

region_get_active() {
    echo "TIMEZONE"
    echo "LOCALE_MAIN"
}
```

**New (`lib/configurator/presets/region.sh`):**
```bash
# Create preset
nds_cfg_preset_create "region" \
    --display "Region" \
    --priority 50

# Declare settings
nds_cfg_setting_create TIMEZONE \
    --type timezone \
    --display "Timezone" \
    --default "UTC"

nds_cfg_setting_create LOCALE \
    --type locale \
    --display "Primary Locale" \
    --default "en_US.UTF-8"

# Clear context
CFG_CONTEXT_PRESET=""
```

**Changes:**
- No `_init()` function wrapper
- Use `nds_cfg_preset_create` at top
- Use `nds_cfg_setting_create` with `--flag value` syntax
- `input=` → `--type`
- `required=` is now inferred (not yet implemented in v4.1)
- Settings are auto-ordered by declaration
- Clear context at end

### 3. Adding Apply Hooks (NEW Feature)

v4.1 supports **apply hooks** that run whenever a setting value changes:

```bash
_country_apply() {
    local country="$1"
    
    # Apply defaults to other settings
    nds_cfg_apply_setting "TIMEZONE" "Europe/Berlin" "auto"
    nds_cfg_apply_setting "LOCALE" "de_DE.UTF-8" "auto"
    nds_cfg_apply_setting "KEYBOARD_LAYOUT" "de" "auto"
}

nds_cfg_settingType_register "country"
```

This hook runs automatically when:
- User enters a value via prompt
- Value is imported from environment
- Value is set programmatically

### 4. Adding Visibility Conditions (NEW Feature)

v4.1 supports conditional visibility:

```bash
nds_cfg_setting_create STATIC_IP \
    --type text \
    --display "Static IP Address" \
    --visible_all "NETWORK_MODE==static"

nds_cfg_setting_create DISK_PASSWORD \
    --type secret \
    --display "Disk Encryption Password" \
    --visible_all "DISK_ENCRYPT==true"
```

**Operators:**
- `==` - equals
- `!=` - not equals
- `<`, `>`, `<=`, `>=` - comparison (numeric or string)

**Conditions:**
- `--visible_all` - ALL conditions must be true (AND logic)
- `--visible_any` - ANY condition must be true (OR logic)

### 5. Exporting Configuration

**Old:**
```bash
nds_configurator_config_export_script
```

**New:**
```bash
# Export only non-default values
nds_cfg_export_nonDefaults

# Export all values
nds_cfg_export_all
```

## New Features in v4.1

### 1. Auto-Registration
- SettingTypes auto-register via `nds_cfg_settingType_register`
- No manual function listing needed

### 2. Hook Caching
- Function pointers cached per setting for performance
- No repeated lookups during validation

### 3. Origin Tracking
Settings track their origin:
- `default` - initial default value
- `env` - imported from environment
- `prompt` - entered by user
- `auto` - set by apply hook
- `manual` - set programmatically

### 4. Visibility Conditions
Settings can be conditionally visible based on other settings.

### 5. Apply Hooks
SettingTypes can define apply hooks that run on value change.

### 6. Exportable Flag
Settings can be marked non-exportable:
```bash
nds_cfg_setting_create COUNTRY \
    --type country \
    --exportable false
```

## Testing Your Migration

1. Start with a simple preset (e.g., region or quick)
2. Test initialization: `nds_cfg_init`
3. Test setting values: `nds_cfg_set HOSTNAME "myhost"`
4. Test getting values: `nds_cfg_get HOSTNAME`
5. Test validation: `nds_cfg_setting_validate HOSTNAME`
6. Test export: `nds_cfg_export_nonDefaults`

## Backward Compatibility

The old API function `nds_configurator_init` still works and redirects to `nds_cfg_init`.

However, the old preset structure and input validators will NOT work. You must migrate them to the new structure.

## Need Help?

The v4.1 blueprint document contains full specifications:
- `bootstrap/readme_configuration3_refactorPlan.md`

Example implementations:
- `lib/configurator/settingTypes/toggle.sh`
- `lib/configurator/settingTypes/country.sh`
- `lib/configurator/presets/region.sh`
