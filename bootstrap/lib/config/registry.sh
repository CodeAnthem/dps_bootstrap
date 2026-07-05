#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration registry & preset loading
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-05
# Description:   Load presets, seed defaults, validate/configure dispatch
# ==================================================================================================

declare -gA PRESET_LOADED=()

# Description: Preset directory (bootstrap/presets preferred, legacy lib/config/presets fallback).
# Arguments:
# - bootstrap_dir: <String> bootstrap root
# Returns:
# - <String> Presets directory path (stdout)
nds_preset_dir() {
    local bootstrap_dir="${1:-${SCRIPT_DIR}}"
    if [[ -d "${bootstrap_dir}/presets" ]]; then
        echo "${bootstrap_dir}/presets"
    else
        echo "${bootstrap_dir}/lib/config/presets"
    fi
}

# Description: Import and register one preset file if not already loaded.
# Arguments:
# - preset_file: <String> Absolute path to preset .sh
# Returns:
# - <Bool> 0 on success
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
    return 0
}

# Description: Load every preset under the presets directory (register metadata + functions).
nds_config_load_presets() {
    local preset_dir preset_file
    preset_dir="$(nds_preset_dir "$SCRIPT_DIR")"
    for preset_file in "${preset_dir}/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        nds_preset_load_file "$preset_file" || return 1
    done
    return 0
}

# Description: Enable only the named presets for an action; load files on demand.
# Arguments:
# - bootstrap_dir: <String> bootstrap root
# - names:         <String...> Preset ids (e.g. disk boot installFlake)
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

nds_config_seed_defaults() {
    local preset
    while IFS= read -r preset; do
        [[ -n "$preset" ]] || continue
        if declare -f "${preset}_defaults" &>/dev/null; then
            "${preset}_defaults"
        fi
    done < <(nds_configurator_preset_get_all_enabled)
    nds_config_snapshot_defaults
    nds_cfg_apply_env_all
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
