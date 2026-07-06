#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager: preset hooks and injection
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Load preset files (builtin + injected), register hooks, enable bundles
# ==================================================================================================

declare -gA PRESET_LOADED=()
declare -gA PRESET_SEEDED=()

# Description: Builtin presets directory.
nds_preset_dir() {
    local bootstrap_dir="${1:-${SCRIPT_DIR}}"
    echo "${bootstrap_dir}/presets"
}

# Description: Import one preset file and register its hooks (defaults/configure/validate/…).
nds_preset_load_file() {
    local preset_file="$1"
    local preset_name priority display

    [[ -f "$preset_file" ]] || return 1
    preset_name="$(basename "$preset_file" .sh)"
    [[ "${PRESET_LOADED[$preset_name]:-}" == "1" ]] && return 0

    nds_import_file "$preset_file" || return 1
    priority="${NDS_PRESET_PRIORITY:-}"
    display="${NDS_PRESET_DISPLAY:-}"
    unset NDS_PRESET_PRIORITY NDS_PRESET_DISPLAY
    if [[ -z "$priority" || -z "$display" ]]; then
        echo "Error: Preset metadata missing in $preset_file (NDS_PRESET_PRIORITY, NDS_PRESET_DISPLAY)" >&2
        return 1
    fi
    nds_preset_register "$preset_name" "$priority" "$display"
    PRESET_LOADED["$preset_name"]=1
    debug "Preset loaded: ${preset_name} (${preset_file})"
    return 0
}

# Description: Load every .sh preset in a directory (builtin or remote .nds/presets).
nds_preset_load_dir() {
    local dir="$1"
    local preset_file loaded=0

    [[ -d "$dir" ]] || return 0
    for preset_file in "${dir}/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        nds_preset_load_file "$preset_file" || return 1
        loaded=1
    done
    [[ "$loaded" -eq 1 ]] || return 0
    return 0
}

# Description: Load all builtin preset hook files (register only — enable via bundle).
nds_config_load_presets() {
    local preset_dir
    preset_dir="$(nds_preset_dir "$SCRIPT_DIR")"
    nds_preset_load_dir "$preset_dir"
}

# Description: Register builtin preset metadata from files without sourcing hooks.
nds_preset_catalog_builtin() {
    local bootstrap_dir="${1:-${SCRIPT_DIR}}"
    local preset_dir preset_file name priority display
    preset_dir="$(nds_preset_dir "$bootstrap_dir")"
    [[ -d "$preset_dir" ]] || return 0

    for preset_file in "${preset_dir}/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        name="$(basename "$preset_file" .sh)"
        priority="$(grep -m1 '^NDS_PRESET_PRIORITY=' "$preset_file" | sed 's/^NDS_PRESET_PRIORITY=//;s/^[[:space:]]*//;s/[[:space:]]*$//')"
        display="$(grep -m1 '^NDS_PRESET_DISPLAY=' "$preset_file" | sed -E 's/^NDS_PRESET_DISPLAY=//; s/^[[:space:]]*"//; s/"[[:space:]]*$//')"
        if [[ -z "$priority" || -z "$display" ]]; then
            echo "Error: Preset metadata missing in $preset_file (NDS_PRESET_PRIORITY, NDS_PRESET_DISPLAY)" >&2
            return 1
        fi
        nds_preset_register_catalog "$name" "$priority" "$display"
    done
    return 0
}

declare -g NDS_PRESET_INJECT_COUNT=0

# Description: Inject presets shipped inside a flake (.nds/preset.sh and .nds/presets/*.sh).
# Sets NDS_PRESET_INJECT_COUNT. Enables each loaded preset and seeds new defaults.
# Arguments:
# - flake_root: <String> Checked-out flake path
# Returns:
# - <Bool> 0 on success
nds_preset_inject_from_flake() {
    local flake_root="$1"
    local nds_root="${flake_root}/.nds"
    local preset_file name count=0

    NDS_PRESET_INJECT_COUNT=0
    [[ -d "$flake_root" ]] || return 1

    if [[ -f "${nds_root}/preset.sh" ]]; then
        nds_preset_load_file "${nds_root}/preset.sh" || return 1
        name="$(basename "${nds_root}/preset.sh" .sh)"
        nds_configurator_preset_enable "$name"
        ((count++)) || true
    fi

    if [[ -d "${nds_root}/presets" ]]; then
        for preset_file in "${nds_root}/presets/"*.sh; do
            [[ -f "$preset_file" ]] || continue
            nds_preset_load_file "$preset_file" || return 1
            name="$(basename "$preset_file" .sh)"
            nds_configurator_preset_enable "$name"
            ((count++)) || true
        done
    fi

    if [[ "$count" -gt 0 ]]; then
        nds_config_seed_new_presets
        debug "Injected ${count} preset(s) from ${flake_root}/.nds"
    fi
    NDS_PRESET_INJECT_COUNT=$count
    return 0
}

# Description: Load extra preset paths declared by an action (absolute paths or dirs).
# Arguments:
# - paths: <String...> Files or directories
nds_preset_load_extra() {
    local path
    for path in "$@"; do
        [[ -n "$path" ]] || continue
        if [[ -d "$path" ]]; then
            nds_preset_load_dir "$path" || return 1
        elif [[ -f "$path" ]]; then
            nds_preset_load_file "$path" || return 1
        else
            warn "Preset path not found: $path"
        fi
    done
    return 0
}

# Description: Enable only named presets for an action; load builtin files on demand.
nds_preset_enable_bundle() {
    local bootstrap_dir="$1"
    shift
    local name preset_dir="${bootstrap_dir}/presets"
    [[ -d "$preset_dir" ]] || preset_dir="$(nds_preset_dir "$bootstrap_dir")"

    for name in "${!PRESET_REGISTRY[@]}"; do
        nds_configurator_preset_disable "$name"
    done

    for name in "$@"; do
        [[ -n "$name" ]] || continue
        if [[ "${PRESET_LOADED[$name]:-}" != "1" ]]; then
            nds_preset_load_file "${preset_dir}/${name}.sh" || return 1
        fi
        nds_configurator_preset_enable "$name"
    done
    return 0
}

# Description: Seed defaults for all enabled presets (first run per preset).
nds_config_seed_defaults() {
    local preset
    while IFS= read -r preset; do
        [[ -n "$preset" ]] || continue
        [[ "${PRESET_SEEDED[$preset]:-}" == "1" ]] && continue
        if declare -f "${preset}_defaults" &>/dev/null; then
            "${preset}_defaults"
        fi
        PRESET_SEEDED["$preset"]=1
    done < <(nds_configurator_preset_get_all_enabled)
    nds_config_snapshot_defaults
    nds_cfg_apply_env_all
}

# Description: Seed defaults only for presets not yet seeded (after injection).
nds_config_seed_new_presets() {
    local preset seeded_any=false
    while IFS= read -r preset; do
        [[ -n "$preset" ]] || continue
        [[ "${PRESET_SEEDED[$preset]:-}" == "1" ]] && continue
        if declare -f "${preset}_defaults" &>/dev/null; then
            "${preset}_defaults"
            seeded_any=true
        fi
        PRESET_SEEDED["$preset"]=1
    done < <(nds_configurator_preset_get_all_enabled)
    if [[ "$seeded_any" == true ]]; then
        nds_config_snapshot_defaults
    fi
    nds_cfg_apply_env_all
}

# Description: Activate injected presets: load paths, enable names, seed new defaults.
# Arguments:
# - paths: <String...> Optional preset files/dirs to load first
# - names: <String...> Preset ids to enable (must already be loaded)
nds_preset_activate_injected() {
  local path name
  local -a paths=() names=()
  local phase="paths"

  for arg in "$@"; do
    [[ "$arg" == "--" ]] && { phase="names"; continue; }
    if [[ "$phase" == "paths" ]]; then
      paths+=("$arg")
    else
      names+=("$arg")
    fi
  done

  if [[ ${#paths[@]} -gt 0 ]]; then
    nds_preset_load_extra "${paths[@]}" || return 1
  fi
  for name in "${names[@]}"; do
    [[ -n "$name" ]] || continue
    [[ "${PRESET_LOADED[$name]:-}" == "1" ]] || {
      error "Preset not loaded: $name"
      return 1
    }
    nds_configurator_preset_enable "$name"
  done
  nds_config_seed_new_presets
  return 0
}

nds_config_preset_validate() {
    local preset="$1"
    if declare -f "${preset}_validate" &>/dev/null; then
        "${preset}_validate"
        return $?
    fi
    return 0
}

nds_config_preset_configure() {
    local preset="$1"
    if declare -f "${preset}_configure" &>/dev/null; then
        "${preset}_configure"
        return $?
    fi
    return 0
}

nds_config_preset_prompt_errors() {
    local preset="$1"
    if declare -f "${preset}_prompt_errors" &>/dev/null; then
        "${preset}_prompt_errors"
        return $?
    fi
    if ! nds_config_preset_validate "$preset" 2>/dev/null; then
        nds_config_preset_configure "$preset"
    fi
    return 0
}

nds_config_preset_summary() {
    local preset="$1" number="${2:-}"
    local display header
    display=$(nds_configurator_preset_get_display "$preset")
    header="${display}:"
    [[ -n "$number" ]] && header="$number. $header"
    nds_ui_h "$header"
    if declare -f "${preset}_summary" &>/dev/null; then
        "${preset}_summary"
    fi
}

nds_configurator_validate_all() {
    local presets=("$@") preset errors=0
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi
    for preset in "${presets[@]}"; do
        nds_config_preset_validate "$preset" 2>/dev/null || ((errors++))
    done
    return $errors
}

nds_configurator_preset_validate() {
    nds_config_preset_validate "$1"
}

nds_configurator_preset_validate_all() {
    nds_configurator_validate_all "$@"
}
