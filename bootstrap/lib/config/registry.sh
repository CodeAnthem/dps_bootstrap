#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration registry & preset loading
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# Description:   Load presets, seed defaults, validate/configure dispatch
# ==================================================================================================

nds_config_load_presets() {
    local preset_file preset_name priority display
    for preset_file in "${SCRIPT_DIR}/lib/config/presets/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        preset_name="$(basename "$preset_file" .sh)"
        nds_import_file "$preset_file" || return 1
        priority="${NDS_PRESET_PRIORITY:-}"
        display="${NDS_PRESET_DISPLAY:-}"
        unset NDS_PRESET_PRIORITY NDS_PRESET_DISPLAY
        if [[ -z "$priority" || -z "$display" ]]; then
            echo "Error: Preset metadata missing in $preset_file (NDS_PRESET_PRIORITY, NDS_PRESET_DISPLAY)" >&2
            return 1
        fi
        nds_preset_register "$preset_name" "$priority" "$display"
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
    nds_config_apply_env
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
