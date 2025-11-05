Below is the **final, corrected and unified “Configurator v4” architecture plan**, with your new structure, naming conventions, and data-key ordering applied everywhere.

This is the **final blueprint** — clean, consistent, and implementation-ready.

---

# 🧠 CONFIGURATOR v4 — FINAL DESIGN & IMPLEMENTATION BLUEPRINT

## 🌲 Project Structure

We now separate each *component* (settings, presets, settingTypes) into its own sub-folder, each with its own “master” and internal logic files.
The root `configurator.sh` only glues components together.

```
lib/configurator.sh                        # Master orchestrator (imports all components)

lib/configurator/
  settingsLogic/                                # Component folder for settings
    settings.sh                            # public API for settings
    logic_visibility.sh                    # visibility & conditions
    logic_envImport.sh                     # env import
    logic_export.sh                        # export
    logic_registry.sh                      # registration helpers
  settingTypes/                            # Folder for settingTypes
    settingTypes.sh                        # public API & registration
    text.sh
    toggle.sh
    choice.sh
    locale.sh
    diskSize.sh
    ...
  presetsLogic/
    presets.sh                             # public API for presets
  presets/                                 # Folder for presets
    disk.sh
    network.sh
    region.sh
    quick.sh
```

Each component manages its own logic.
`configurator.sh` only initializes components in the correct order and exposes global helper APIs.

---

## 🔤 NAMING PATTERNS (Consistent Everywhere)

| Concept                       | Pattern                         | Example                                                                          |
| ----------------------------- | ------------------------------- | -------------------------------------------------------------------------------- |
| **SettingType functions**     | `_<type>_<verb>`                | `_diskSize_validate`, `_locale_promptHint`                                       |
| **SettingType registry keys** | `"${type}::${verb}"`            | `CFG_SETTINGTYPES["diskSize::validate"]="_diskSize_validate"`                    |
| **Preset functions**          | `_<preset>_<verb>`              | `_network_validate`, `_disk_prepare`                                             |
| **Visibility**                | `nds_cfg_setting_isVisible VAR` | not `nds_cfg_is_visible`                                                         |
| **Config arrays**             | first key = object name         | `CFG_SETTINGS["HOSTNAME::type"]="text"`, `CFG_PRESETS["network::priority"]="20"` |

Error message handler renamed from **`errorMsg` → `errorCode`**.
SettingType registry now uses `...::errorCode` key and `_diskSize_errorCode` function.

---

## ⚙️ 1. SETTINGTYPES (Reusable Input Logic)

### File example: `lib/configurator/settingTypes/diskSize.sh`

```bash
_diskSize_promptHint() { echo "(e.g., 8G, 500M, 1T)"; }

_diskSize_validate() {
  local size="$1"
  [[ "$size" =~ ^[0-9]+[KMGT]?$ ]]
}

_diskSize_errorCode() { echo "Invalid disk size format (examples: 8G, 500M, 1T)"; }

nds_cfg_settingType_register "diskSize"
```

### Registration (`settingTypes.sh`)

`nds_cfg_settingType_register <type>` auto-detects functions matching `_<type>_` prefix and fills:

```
CFG_SETTINGTYPES["${type}::validate"]="_${type}_validate"
CFG_SETTINGTYPES["${type}::errorCode"]="_${type}_errorCode"
CFG_SETTINGTYPES["${type}::prompt"]="_${type}_prompt"
...
```

If a hook is missing, a fallback is assigned automatically.

---

## ⚙️ 2. SETTINGS

### Purpose

Define unique configuration variables and bind them to a preset and a SettingType.

### Declaration

```bash
nds_cfg_setting_create DISK_TARGET \
  --type text \
  --display "Target device" \
  --default "/dev/sda" \
  --visible_all "DISK_ENCRYPT==true" \
  --visible_any "SEPARATE_HOME!=true" \
  --options "systemd-boot|grub|refind"
```

If `--preset` is **omitted**, it binds to the current preset context (set via `nds_cfg_preset_create`).
If `--default` is **omitted**, it defaults to empty string.

### Stored Keys

(all start with `VAR::`)

```
CFG_SETTINGS["DISK_TARGET::type"]="text"
CFG_SETTINGS["DISK_TARGET::preset"]="disk"
CFG_SETTINGS["DISK_TARGET::display"]="Target device"
CFG_SETTINGS["DISK_TARGET::default"]="/dev/sda"
CFG_SETTINGS["DISK_TARGET::value"]="/dev/sda"
CFG_SETTINGS["DISK_TARGET::visible_all"]="DISK_ENCRYPT==true"
CFG_SETTINGS["DISK_TARGET::visible_any"]="SEPARATE_HOME!=true"
CFG_SETTINGS["DISK_TARGET::exportable"]="true"
CFG_SETTINGS["DISK_TARGET::attr::options"]="systemd-boot|grub|refind"
```

### Registry helpers (`logic_registry.sh`)

```bash
nds_cfg_setting_create VAR [args...]      # create or modify
nds_cfg_setting_exists VAR
nds_cfg_setting_all                       # list all vars
nds_cfg_setting_get VAR FIELD
nds_cfg_setting_set VAR FIELD VALUE [ORIGIN]
```

### Visibility API (logic_visibility.sh)

```bash
nds_cfg_setting_isVisible VAR
```

Supports operators `== != < > <= >=` (numeric or string comparison).

---

## ⚙️ 3. PRESETS

### Purpose

Group settings, define ordering, metadata, and optional cross-setting validation.

### Declaration Example

```bash
nds_cfg_preset_create "network" \
  --display "Network Settings" \
  --priority 20

nds_cfg_setting_create NETWORK_MODE \
  --type choice --default "dhcp" \
  --display "Network Mode" \
  --options "dhcp|static"

nds_cfg_setting_create NETWORK_IP \
  --type text --display "Static IP" \
  --visible_all "NETWORK_MODE==static"

_network_validate() {
  local mode=$(nds_cfg_get NETWORK_MODE)
  local ip=$(nds_cfg_get NETWORK_IP)
  [[ "$mode" == "dhcp" || -n "$ip" ]]
}
```

If `_network_validate` exists, it’s auto-detected at `nds_cfg_preset_create`.

### Stored Keys

(all start with `PRESET::`)

```
CFG_PRESETS["network::display"]="Network Settings"
CFG_PRESETS["network::priority"]="20"
CFG_PRESETS["network::order"]="NETWORK_MODE NETWORK_IP"
CFG_PRESETS["network::validate"]="_network_validate"
```

---

## ⚙️ 4. LOGIC COMPONENTS

Each logic lives under the **settings/logic** folder since visibility, import, and export operate on settings.

### 4.1 `logic_visibility.sh`

```bash
nds_cfg_setting_isVisible VAR
```

* Evaluates `VAR::visible_all` and `VAR::visible_any`.
* Parses tokens `A==B`, `A!=B`, `<`, `>`, `<=`, `>=`.
* Numeric compare if both values numeric; otherwise string compare.
* Returns 0 if visible, 1 if hidden.

### 4.2 `logic_envImport.sh`

```bash
nds_cfg_env_import PREFIX
```

* Iterate `CFG_ALL_SETTINGS`.
* If env var `${PREFIX}${VAR}` exists:

  * Normalize via `_TYPE_normalize`.
  * Validate via `_TYPE_validate`.
  * Apply via `_TYPE_apply` (if defined).
  * Store to `CFG_SETTINGS["VAR::value"]`.
  * Mark `CFG_SETTINGS["VAR::origin"]="env"`.
    ✅ Fixes the former “apply only on prompt” bug.

### 4.3 `logic_export.sh`

```bash
nds_cfg_export_nonDefaults
```

* Print:

  ```
  # Config export at 2025-11-05
  # preset: network
  export NDS_NETWORK_MODE="static"
  ```
* Skip if:

  * current == default
  * `VAR::exportable` == "false"

### 4.4 `logic_registry.sh`

Handles registration and global lists.

Arrays:

```bash
CFG_ALL_SETTINGS=()
CFG_ALL_PRESETS=()
CFG_ALL_SETTINGTYPES=()
```

Helpers:

```bash
nds_cfg_setting_exists VAR
nds_cfg_setting_all
nds_cfg_preset_all
nds_cfg_settingType_get TYPE HOOK
```

---

## ⚙️ 5. CONFIGURATOR MASTER (lib/configurator.sh)

Responsible for initialization only.

### Init Flow

```bash
nds_cfg_init() {
  # 1. Load settingTypes
  nds_import_dir "${LIB_DIR}/configurator/settingTypes" false || exit 1

  # 2. Load presets
  nds_import_dir "${LIB_DIR}/configurator/presets" false || exit 1

  ect...
}
```

### Example Helper APIs

```bash
nds_cfg_get()  { echo "${CFG_SETTINGS["$1::value"]}"; }
nds_cfg_set()  { nds_cfg_apply_setting "$1" "$2" "manual"; }

nds_cfg_apply_setting() {
  local var="$1" value="$2" origin="${3:-auto}"
  local type="${CFG_SETTINGS["$var::type"]}"

  # normalize
  local normalize="${CFG_SETTINGTYPES["${type}::normalize"]}"
  [[ -n "$normalize" ]] && value=$("$normalize" "$value")

  # validate
  local validate="${CFG_SETTINGTYPES["${type}::validate"]}"
  if ! "$validate" "$value"; then
    local err="${CFG_SETTINGTYPES["${type}::errorCode"]}"
    "$err" "$value" >&2
    return 1
  fi

  CFG_SETTINGS["$var::value"]="$value"
  CFG_SETTINGS["$var::origin"]="$origin"

  # apply hook if any
  local apply="${CFG_SETTINGTYPES["${type}::apply"]}"
  [[ -n "$apply" ]] && "$apply" "$value"
}
```

---

## ⚙️ 6. Example Preset & Type

### `lib/configurator/presets/region.sh`

```bash
nds_cfg_preset_create "region" \
  --display "Regional Settings" \
  --priority 5

nds_cfg_setting_create LOCALE \
  --type locale --default "en_US.UTF-8" \
  --display "System Locale"

nds_cfg_setting_create KEYMAP \
  --type text --default "us" \
  --display "Keyboard Layout"

nds_cfg_setting_create TIMEZONE \
  --type text --default "America/New_York" \
  --display "Timezone"

# Preset validation (optional)
_region_validate() {
  local locale=$(nds_cfg_get LOCALE)
  [[ -n "$locale" ]]
}
```

### `lib/configurator/settingTypes/country.sh`

```bash
_country_validate() { [[ "$1" =~ ^[a-z]{2}$ ]]; }
_country_errorCode() { echo "Must be a 2-letter lowercase code."; }

_country_apply() {
  local val="$1"
  case "$val" in
    ch)
      nds_cfg_apply_setting LOCALE "de_CH.UTF-8"
      nds_cfg_apply_setting KEYMAP "ch"
      nds_cfg_apply_setting TIMEZONE "Europe/Zurich"
      ;;
    us)
      nds_cfg_apply_setting LOCALE "en_US.UTF-8"
      nds_cfg_apply_setting KEYMAP "us"
      nds_cfg_apply_setting TIMEZONE "America/New_York"
      ;;
  esac
}

nds_cfg_settingType_register "country"
```

---

## ⚙️ 7. Example of Consistent Data Storage

**After loading region preset:**

```
CFG_PRESETS["region::display"]="Regional Settings"
CFG_PRESETS["region::priority"]="5"
CFG_PRESETS["region::order"]="COUNTRY LOCALE KEYMAP TIMEZONE"
CFG_PRESETS["region::validate"]="_region_validate"

CFG_SETTINGS["COUNTRY::type"]="country"
CFG_SETTINGS["LOCALE::type"]="locale"
CFG_SETTINGS["KEYMAP::type"]="text"
CFG_SETTINGS["TIMEZONE::type"]="text"
```

---

## ⚙️ 8. Initialization & Flow Summary

```
nds_cfg_init
 ├─ load all SettingTypes → CFG_SETTINGTYPES
 ├─ load all Presets → CFG_PRESETS + CFG_SETTINGS
     ↓
nds_cfg_env_import NDS_
 ├─ normalize → validate → apply hooks
     ↓
prompt loop (external UI)
 ├─ for each preset
 │    ├─ for each setting in preset
 │    │     ├─ nds_cfg_setting_isVisible
 │    │     ├─ prompt (via SettingType)
 │    │     ├─ nds_cfg_apply_setting (validate+apply)
 │    └─ optional preset-level validation
     ↓
nds_cfg_export_nonDefaults
```

---

## ⚙️ 9. Consistent Singular Naming

✅ `nds_cfg_setting_create`
✅ `nds_cfg_setting_isVisible`
✅ `nds_cfg_preset_create`
✅ `nds_cfg_settingType_register`
✅ `nds_cfg_export_nonDefaults`

No plural/singular mix anywhere.

---

## ✅ Highlights of v4 Changes

| Area                  | Change                                                                                             |
| --------------------- | -------------------------------------------------------------------------------------------------- |
| **Project structure** | Each component (settings, presets, settingTypes) has its own master + logic folder; no workflow.sh |
| **Naming pattern**    | `_type_verb` and `_preset_verb`; consistent registry key ordering                                  |
| **Error handler**     | `errorMsg` → `errorCode`                                                                           |
| **Data keys**         | Always `VAR::field`, `PRESET::field`                                                               |
| **Visibility API**    | Renamed to `nds_cfg_setting_isVisible`                                                             |
| **Country vs locale** | Fixed — country = quick shortcut, locale = real system setting                                     |
| **Defaults**          | Optional, empty by default — no need to pass `--default ""`                                        |
| **Auto detection**    | Validation `_preset_validate` auto-registered                                                      |
| **Clarity**           | Everything predictable from file name and function name                                            |

---

## 🧾 TL;DR — CONFIGURATOR v4

> * Components: **settingTypes**, **settings**, **presets** — each with clear ownership and logic files.
> * Naming convention: `_type_verb`, `_preset_verb`, array keys start with name.
> * Auto-detection: no manual registration lists.
> * Live visibility, numeric/string comparisons.
> * “Apply” runs for all updates (prompt + env).
> * Export only changed + exportable settings.
> * Full separation of quick-presets (like country) from actual system settings (like locale).

---

Would you like me to now generate the **skeleton directory structure and empty/stub Bash files** following this final v4 plan (so the next AI can code directly inside them)?
