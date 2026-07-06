#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-06
# Description:   Flat config storage, preset registry, env import/export
# ==================================================================================================

declare -gA CONFIG_DATA=()
declare -gA CONFIG_DEFAULTS=()
declare -gA PRESET_REGISTRY=()
declare -gA PRESET_META=()

# Keys always shown in the concise export even when unchanged, because they are
# auto-detected (not typed by the user) and useful to pin for a repeat install.
_NDS_EXPORT_ALWAYS="DISK_TARGET BOOT_UEFI_MODE BOOT_LOADER PLATFORM_RUN_ON_VM PLATFORM_VM_TYPE"

# Shown in concise export whenever non-empty (even if equal to default).
_NDS_EXPORT_WHEN_SET="INSTALL_MODE FLAKE_REPO_URL FLAKE_LOCAL_PATH FLAKE_HOST FLAKE_INSTALL_PATH FLAKE_HOST_DIR FLAKE_HARDWARE_PLACEMENT"

# Machine/hardware-specific keys. The concise export splits these from portable
# policy so a portable profile can be reused across machines untouched.
_NDS_EXPORT_HARDWARE="DISK_TARGET DISK_STRATEGY DISK_FS_TYPE DISK_SWAP_SIZE_MIB DISK_DISKO_CONFIG BOOT_UEFI_MODE BOOT_LOADER PLATFORM_RUN_ON_VM PLATFORM_VM_TYPE PLATFORM_VM_GUEST_TOOLS NETWORK_HOSTNAME NETWORK_IP NETWORK_MASK NETWORK_GATEWAY REMOTE_TARGET_IP"

# Derived keys never shown in the concise export — reconstructed from other keys
# (FLAKE_LOCATION / FLAKE_SOURCE are inferred from FLAKE_REPO_URL / FLAKE_LOCAL_PATH).
_NDS_EXPORT_SKIP="FLAKE_LOCATION FLAKE_SOURCE GIT_AUTH_METHOD GIT_DEPLOY_KEY_IMPORT_PATH CURRENT_ACTION RUNTIME_DIR ACTION ACTION_PREVIEW_SKIP SKIP_MENU CONFIG_CONFIRM_SKIP INSTALL_CONFIRM_SKIP REMOTE_CONFIRM_SKIP GIT_AUTH_SKIP DISK_FORMAT_CONFIRM_SKIP BACKUP_CONFIRM_SKIP REBOOT_SKIP SCAFFOLD_OVERWRITE_SKIP HARDWARE_OVERWRITE_SKIP PREFLIGHT_WARN_SKIP PROMPTS_SKIP AUTO_CONFIRM"

# Menu skip flags — exported false by default so users can enable selective automation.
_NDS_MENU_SKIP_FLAGS=(
    ACTION_PREVIEW_SKIP
    SKIP_MENU
    CONFIG_CONFIRM_SKIP
    INSTALL_CONFIRM_SKIP
    REMOTE_CONFIRM_SKIP
    GIT_AUTH_SKIP
    DISK_FORMAT_CONFIRM_SKIP
    BACKUP_CONFIRM_SKIP
    REBOOT_SKIP
    SCAFFOLD_OVERWRITE_SKIP
    HARDWARE_OVERWRITE_SKIP
    PREFLIGHT_WARN_SKIP
    PROMPTS_SKIP
    AUTO_CONFIRM
)

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

_nds_export_is_when_set() {
    local key="$1" a
    for a in $_NDS_EXPORT_WHEN_SET; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_nds_export_is_hardware() {
    local key="$1" a
    for a in $_NDS_EXPORT_HARDWARE; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

# Whether a key belongs in the concise export: auto-detected essentials always,
# otherwise only when the user changed it from the seeded default.
_nds_export_is_skipped() {
    local key="$1" a
    for a in $_NDS_EXPORT_SKIP; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_nds_export_should_include() {
    local key="$1" cur="${CONFIG_DATA[$1]}"
    _nds_export_is_skipped "$key" && return 1
    if _nds_export_is_when_set "$key"; then
        [[ -n "$cur" ]]
        return
    fi
    if _nds_export_is_always "$key"; then
        [[ -n "$cur" ]]
        return
    fi
    if [[ -v CONFIG_DEFAULTS[$key] && "$cur" == "${CONFIG_DEFAULTS[$key]}" ]]; then
        return 1
    fi
    [[ -n "$cur" ]]
}

# Concise export, one `export` per line (plain listing). Only values the user
# set, plus the auto-detected essentials.
nds_configurator_config_export_modified() {
    local varname
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        _nds_export_should_include "$varname" || continue
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# Concise export as grouped sections — one `export` per line. Portable settings,
# machine-specific keys, then menu skip flags (default false).
nds_configurator_config_export_grouped() {
    local varname portable=0 hardware=0
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        _nds_export_should_include "$varname" || continue
        if _nds_export_is_hardware "$varname"; then
            if [[ "$hardware" -eq 0 ]]; then
                [[ "$portable" -gt 0 ]] && echo ""
                echo "# This machine only — disk / boot / VM / static addressing:"
                hardware=1
            fi
            echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
        else
            if [[ "$portable" -eq 0 ]]; then
                echo "# Configuration — portable (reuse on any machine):"
                portable=1
            fi
            echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
        fi
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)

    echo ""
    echo "# Menu control — set any SKIP flag to true to skip that step (false = interactive):"
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        echo "export NDS_ACTION=\"${NDS_CURRENT_ACTION}\""
    fi
    local flag
    for flag in "${_NDS_MENU_SKIP_FLAGS[@]}"; do
        echo "export NDS_${flag}=\"false\""
    done
}

# Description: Sync FLAKE_LOCATION / FLAKE_SOURCE from FLAKE_REPO_URL or FLAKE_LOCAL_PATH.
nds_cfg_sync_derived_flake() {
    local loc repo local_path src
    loc="$(nds_cfg_get FLAKE_LOCATION)"
    repo="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"

    if [[ -n "$loc" && -z "$repo" && -z "$local_path" ]]; then
        src=$(nds_detect_flake_source "$loc")
        nds_cfg_set FLAKE_SOURCE "$src"
        if [[ "$src" == remote ]]; then
            nds_cfg_set FLAKE_REPO_URL "$loc"
            nds_cfg_set FLAKE_LOCAL_PATH ""
        else
            nds_cfg_set FLAKE_LOCAL_PATH "$loc"
            nds_cfg_set FLAKE_REPO_URL ""
        fi
        return 0
    fi

    if [[ -n "$repo" ]]; then
        nds_cfg_set FLAKE_LOCATION "$repo"
        nds_cfg_set FLAKE_SOURCE "remote"
        nds_cfg_set FLAKE_LOCAL_PATH ""
    elif [[ -n "$local_path" ]]; then
        nds_cfg_set FLAKE_LOCATION "$local_path"
        nds_cfg_set FLAKE_SOURCE "local"
        nds_cfg_set FLAKE_REPO_URL ""
    fi
}

# Description: Apply every NDS_* environment variable to CONFIG_DATA, then sync derived keys.
nds_cfg_apply_env_all() {
    local env_name key
    while IFS= read -r env_name; do
        [[ "$env_name" == NDS_* ]] || continue
        key="${env_name#NDS_}"
        [[ -n "${!env_name:-}" ]] || continue
        CONFIG_DATA["$key"]="${!env_name}"
        debug "Env: ${env_name}=${!env_name}"
    done < <(compgen -e | grep '^NDS_' || true)
    nds_cfg_sync_derived_flake
}

nds_config_apply_env() {
    nds_cfg_apply_env_all
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

# Description: Register preset metadata without loading hooks (catalog entry, disabled).
nds_preset_register_catalog() {
    local name="$1"
    local priority="$2"
    local display="$3"
    PRESET_REGISTRY["$name"]="disabled"
    PRESET_META["${name}__priority"]="$priority"
    PRESET_META["${name}__display"]="$display"
}

nds_configurator_preset_enable() {
    PRESET_REGISTRY["$1"]="enabled"
}

nds_configurator_preset_disable() {
    [[ -n "${PRESET_REGISTRY[$1]:-}" ]] || return 0
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
    local preset preset_dir preset_file
    preset_dir="$(nds_preset_dir "$bootstrap_dir")"
    for preset_file in "${preset_dir}/"*.sh; do
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
    nds_ui_b "Paste the lines below before re-running NDS to replay this configuration."
    nds_ui_b "Each setting is on its own line. Menu SKIP flags default to false"
    nds_ui_b "(interactive). Set individual flags to true, or use --auto-confirm for full auto."
    nds_ui_b ""
    while IFS= read -r line; do
        nds_ui_i "$line"
    done < <(nds_configurator_config_export_grouped)
    nds_ui_b ""
}

nds_configurator_confirm_config_saved() {
    if nds_skip_menu NDS_CONFIG_CONFIRM_SKIP; then
        log "Configuration review confirmation skipped"
        return 0
    fi
    nds_askUserToProceed "Continue to installation review" || return 1
    return 0
}
