#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager: preset hooks and injection
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-05
# Description:   Load preset files (builtin + injected), register hooks, enable bundles
# ==================================================================================================

declare -gA PRESET_LOADED=()
declare -gA PRESET_SEEDED=()
# Set while sourcing a preset so nds_preset_register_hooks can omit the name.
declare -g NDS_PRESET_LOADING=""

# Description: Builtin presets directory.
nds_preset_dir() {
    local bootstrap_dir="${1:-${SCRIPT_DIR}}"
    echo "${bootstrap_dir}/settings/builtin"
}

# Description: Register hook function names for a preset (key=fn pairs).
# Call from a preset file after defining its functions. When sourced via
# nds_preset_load_file, the name may be omitted (uses NDS_PRESET_LOADING).
# Arguments:
# - name?: <String> Preset id (optional when NDS_PRESET_LOADING is set)
# - pairs: <String...> hook=function_name
#          hooks: defaults|configure|validate|summary|prompt_errors
nds_preset_register_hooks() {
    local name="" pair key fn
    if [[ $# -gt 0 && "$1" != *=* ]]; then
        name="$1"
        shift
    else
        name="${NDS_PRESET_LOADING:-}"
    fi
    [[ -n "$name" ]] || {
        echo "Error: nds_preset_register_hooks: preset name required" >&2
        return 1
    }
    for pair in "$@"; do
        [[ "$pair" == *=* ]] || {
            echo "Error: nds_preset_register_hooks: expected hook=fn, got '$pair'" >&2
            return 1
        }
        key="${pair%%=*}"
        fn="${pair#*=}"
        case "$key" in
            defaults|configure|validate|summary|prompt_errors) ;;
            *)
                echo "Error: nds_preset_register_hooks: unknown hook '$key'" >&2
                return 1
                ;;
        esac
        [[ -n "$fn" ]] || continue
        PRESET_HOOKS["${name}__${key}"]="$fn"
    done
    return 0
}

# Description: Resolve hook function name for a preset (registered, then name fallback).
# Arguments:
# - preset: <String> Preset id
# - hook:   <String> defaults|configure|validate|summary|prompt_errors
# Returns:
# - <String> function name on stdout; non-zero when missing
_nds_preset_hook_fn() {
    local preset="$1" hook="$2"
    local fn="${PRESET_HOOKS[${preset}__${hook}]:-}"
    if [[ -n "$fn" ]]; then
        declare -f "$fn" &>/dev/null || return 1
        printf '%s\n' "$fn"
        return 0
    fi
    # Compat: unmigrated presets still using ${name}_${hook}
    fn="${preset}_${hook}"
    declare -f "$fn" &>/dev/null || return 1
    printf '%s\n' "$fn"
    return 0
}

# Description: True when a preset has a callable hook (registered or name fallback).
_nds_preset_has_hook() {
    local preset="$1" hook="$2"
    _nds_preset_hook_fn "$preset" "$hook" &>/dev/null
}

# Description: Import one preset file and register its hooks (defaults/configure/validate/…).
nds_preset_load_file() {
    local preset_file="$1"
    local preset_name priority display

    [[ -f "$preset_file" ]] || return 1
    preset_name="$(basename "$preset_file" .sh)"
    [[ "${PRESET_LOADED[$preset_name]:-}" == "1" ]] && return 0

    NDS_PRESET_LOADING="$preset_name"
    nds_import_file "$preset_file" || {
        NDS_PRESET_LOADING=""
        return 1
    }
    NDS_PRESET_LOADING=""
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
        nds_cfg_preset_enable "$name"
        ((count++)) || true
    fi

    if [[ -d "${nds_root}/presets" ]]; then
        for preset_file in "${nds_root}/presets/"*.sh; do
            [[ -f "$preset_file" ]] || continue
            nds_preset_load_file "$preset_file" || return 1
            name="$(basename "$preset_file" .sh)"
            nds_cfg_preset_enable "$name"
            ((count++)) || true
        done
    fi

    if [[ "$count" -gt 0 ]]; then
        nds_cfg_seed_new_presets
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
    local name preset_dir="${bootstrap_dir}/settings/builtin"
    [[ -d "$preset_dir" ]] || preset_dir="$(nds_preset_dir "$bootstrap_dir")"

    for name in "${!PRESET_REGISTRY[@]}"; do
        nds_cfg_preset_disable "$name"
    done

    for name in "$@"; do
        [[ -n "$name" ]] || continue
        if [[ "${PRESET_LOADED[$name]:-}" != "1" ]]; then
            nds_preset_load_file "${preset_dir}/${name}.sh" || return 1
        fi
        nds_cfg_preset_enable "$name"
    done
    return 0
}

# Description: Seed defaults for all enabled presets (first run per preset).
nds_cfg_seed_defaults() {
    local preset fn
    while IFS= read -r preset; do
        [[ -n "$preset" ]] || continue
        [[ "${PRESET_SEEDED[$preset]:-}" == "1" ]] && continue
        if fn="$(_nds_preset_hook_fn "$preset" defaults)"; then
            "$fn"
        fi
        PRESET_SEEDED["$preset"]=1
    done < <(nds_cfg_preset_get_all_enabled)
    nds_cfg_snapshot_defaults
    nds_cfg_apply_env_all
}

# Description: Seed defaults only for presets not yet seeded (after injection).
nds_cfg_seed_new_presets() {
    local preset fn seeded_any=false
    while IFS= read -r preset; do
        [[ -n "$preset" ]] || continue
        [[ "${PRESET_SEEDED[$preset]:-}" == "1" ]] && continue
        if fn="$(_nds_preset_hook_fn "$preset" defaults)"; then
            "$fn"
            seeded_any=true
        fi
        PRESET_SEEDED["$preset"]=1
    done < <(nds_cfg_preset_get_all_enabled)
    if [[ "$seeded_any" == true ]]; then
        nds_cfg_snapshot_defaults
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
    nds_cfg_preset_enable "$name"
  done
  nds_cfg_seed_new_presets
  return 0
}

nds_cfg_preset_validate() {
    local preset="$1" fn
    if fn="$(_nds_preset_hook_fn "$preset" validate)"; then
        "$fn"
        return $?
    fi
    return 0
}

nds_cfg_preset_configure() {
    local preset="$1" fn
    if fn="$(_nds_preset_hook_fn "$preset" configure)"; then
        "$fn"
        return $?
    fi
    return 0
}

nds_cfg_preset_prompt_errors() {
    local preset="$1" fn
    if fn="$(_nds_preset_hook_fn "$preset" prompt_errors)"; then
        "$fn"
        return $?
    fi
    if ! nds_cfg_preset_validate "$preset" 2>/dev/null; then
        nds_cfg_preset_configure "$preset"
    fi
    return 0
}

nds_cfg_preset_summary() {
    local preset="$1" number="${2:-}"
    local display header fn
    display=$(nds_cfg_preset_get_display "$preset")
    header="${display}:"
    [[ -n "$number" ]] && header="$number. $header"
    nds_ui_h "$header"
    if fn="$(_nds_preset_hook_fn "$preset" summary)"; then
        "$fn"
    fi
}

nds_cfg_validate_all() {
    local presets=("$@") preset errors=0
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_cfg_preset_get_all_enabled)
    fi
    for preset in "${presets[@]}"; do
        nds_cfg_preset_validate "$preset" 2>/dev/null || ((errors++))
    done
    return $errors
}
