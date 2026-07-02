#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# Description:   Flat config storage, preset registry, env import/export
# ==================================================================================================

declare -gA CONFIG_DATA=()
declare -gA CONFIG_DEFAULTS=()
declare -gA PRESET_REGISTRY=()
declare -gA PRESET_META=()

# Keys always shown in the concise export even when unchanged, because they are
# auto-detected (not typed by the user) and useful to pin for a repeat install.
_NDS_EXPORT_ALWAYS="DISK_TARGET BOOT_UEFI_MODE BOOT_LOADER RUN_ON_VM VM_TYPE"

# =============================================================================
# CONFIG ACCESS
# =============================================================================

nds_cfg_get() {
    echo "${CONFIG_DATA[$1]:-${2:-}}"
}

nds_cfg_set() {
    CONFIG_DATA["$1"]="$2"
}

nds_cfg_is() {
    [[ "$(nds_cfg_get "$1")" == "$2" ]]
}

nds_cfg_true() {
    nds_cfg_is "$1" true
}

nds_configurator_config_get() { nds_cfg_get "$@"; }
nds_configurator_config_set() { nds_cfg_set "$@"; }

# Legacy — preset name ignored; values are flat in CONFIG_DATA.
nds_config_get() {
    nds_cfg_get "$2" "${3:-}"
}

nds_configurator_config_get_env() {
    local varname="$1"
    local default="${2:-}"
    local env_var="NDS_${varname}"
    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
    else
        nds_cfg_get "$varname" "$default"
    fi
}

# Full export: every config value. Used for the install backup bundle so a
# future run can reproduce the machine exactly.
nds_configurator_config_export_script() {
    local varname
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# Snapshot the seeded defaults so the concise export can tell what the user
# actually changed. Call after presets seed defaults, before env/menu edits.
nds_config_snapshot_defaults() {
    CONFIG_DEFAULTS=()
    local k
    for k in "${!CONFIG_DATA[@]}"; do
        CONFIG_DEFAULTS["$k"]="${CONFIG_DATA[$k]}"
    done
}

_nds_export_is_always() {
    local key="$1" a
    for a in $_NDS_EXPORT_ALWAYS; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

# Concise export: only values that differ from their seeded default (i.e. what
# the user actually set), plus the auto-detected essentials. Used for the
# on-screen export block so it isn't cluttered with untouched defaults.
nds_configurator_config_export_modified() {
    local varname cur def
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        cur="${CONFIG_DATA[$varname]}"
        if _nds_export_is_always "$varname"; then
            [[ -n "$cur" ]] && echo "export NDS_${varname}=\"${cur}\""
            continue
        fi
        # Unchanged from default -> skip.
        if [[ -v CONFIG_DEFAULTS[$varname] ]]; then
            def="${CONFIG_DEFAULTS[$varname]}"
            [[ "$cur" == "$def" ]] && continue
        fi
        # Never seeded and still empty -> nothing worth exporting.
        [[ -z "$cur" ]] && continue
        echo "export NDS_${varname}=\"${cur}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

nds_config_apply_env() {
    local varname
    for varname in "${!CONFIG_DATA[@]}"; do
        local env_var="NDS_${varname}"
        if [[ -n "${!env_var:-}" ]]; then
            CONFIG_DATA["$varname"]="${!env_var}"
            debug "Env override: $env_var=${!env_var}"
        fi
    done
}

# =============================================================================
# PRESET REGISTRY
# =============================================================================

nds_preset_register() {
    local name="$1"
    local priority="$2"
    local display="$3"
    PRESET_REGISTRY["$name"]="enabled"
    PRESET_META["${name}__priority"]="$priority"
    PRESET_META["${name}__display"]="$display"
}

nds_configurator_preset_enable() {
    PRESET_REGISTRY["$1"]="enabled"
}

nds_configurator_preset_disable() {
    PRESET_REGISTRY["$1"]="disabled"
}

nds_configurator_preset_set_priority() {
    PRESET_META["${1}__priority"]="$2"
}

nds_configurator_preset_set_display() {
    PRESET_META["${1}__display"]="$2"
}

nds_configurator_preset_get_priority() {
    echo "${PRESET_META[${1}__priority]:-50}"
}

nds_configurator_preset_get_display() {
    local preset="$1"
    local display="${PRESET_META[${preset}__display]:-}"
    if [[ -z "$display" ]]; then
        display="$(echo "${preset^}" | tr '_' ' ')"
    fi
    echo "$display"
}

_nds_configurator_sort_presets() {
    local presets=("$@")
    [[ ${#presets[@]} -eq 0 ]] && return 0
    local sorted=() preset priority
    for preset in "${presets[@]}"; do
        priority=$(nds_configurator_preset_get_priority "$preset")
        sorted+=("${priority}:${preset}")
    done
    printf '%s\n' "${sorted[@]}" | sort -t: -k1,1n -k2,2 | cut -d: -f2
}

nds_configurator_preset_get_all_enabled() {
    local presets=() preset
    for preset in "${!PRESET_REGISTRY[@]}"; do
        [[ "${PRESET_REGISTRY[$preset]}" == "enabled" ]] && presets+=("$preset")
    done
    _nds_configurator_sort_presets "${presets[@]}"
}

nds_configurator_reset_for_action() {
    local bootstrap_dir="${1:?bootstrap dir}"
    local preset preset_file
    for preset_file in "${bootstrap_dir}/lib/config/presets/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        preset=$(basename "$preset_file" .sh)
        nds_configurator_preset_enable "$preset"
        unset "PRESET_META[${preset}__display]"
    done
    for preset in installFlake remoteAction; do
        nds_configurator_preset_disable "$preset"
        unset "PRESET_META[${preset}__display]"
        unset "PRESET_META[${preset}__priority]"
    done
}

nds_configurator_print_config_backup() {
    local line
    section_header "Configuration export"
    nds_ui_b "If you plan to finish installation, you do not need to copy anything here."
    nds_ui_b "NDS includes the full configuration in the install backup zip when installation completes."
    nds_ui_b "Below are only the values you changed (plus auto-detected disk/boot essentials):"
    nds_ui_b ""
    while IFS= read -r line; do
        nds_ui_i "$line"
    done < <(nds_configurator_config_export_modified)
    nds_ui_b ""
}

nds_configurator_confirm_config_saved() {
    nds_askUserToProceed "Continue to installation review" || return 1
    return 0
}
