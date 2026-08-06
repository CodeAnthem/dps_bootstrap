#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-05
# Description:   Flat config storage, preset registry, env import/export
# ==================================================================================================

declare -gA CONFIG_DATA=()
declare -gA CONFIG_DEFAULTS=()
declare -gA PRESET_REGISTRY=()
declare -gA PRESET_META=()
# Hook function names: PRESET_HOOKS["${preset}__validate"]="disk_validate" …
declare -gA PRESET_HOOKS=()

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
_NDS_EXPORT_SKIP="FLAKE_LOCATION FLAKE_SOURCE GIT_AUTH_ROUTE GIT_AUTH_MODE GIT_IMPORT_KEY_PATH GIT_SSH_KEY_TYPE GIT_SSH_KEY_REGISTER_METHOD GIT_CLOSURE_ROUTE GIT_SSH_KEY_USE_QR GIT_SSH_KEY_DISPLAY GIT_SSH_KEY_GH_AUTO GIT_SSH_KEY_TITLE_COLLISION GIT_GH_BIN GIT_GH_PREFETCH_DONE GIT_ACCESS_VERIFIED GIT_ACCESS_HOST GIT_ACCESS_OWNER GIT_ACCESS_REPO GIT_ACCESS_METHOD GIT_PERSIST_ACCESS GIT_ACCESS_STRATEGY CURRENT_ACTION RUNTIME_DIR INSTALL_DETAIL_LOG INSTALL_LOG ACTION ACTION_PREVIEW_SKIP SKIP_MENU CONFIG_CONFIRM_SKIP INSTALL_CONFIRM_SKIP REMOTE_CONFIRM_SKIP GIT_AUTH_SKIP DISK_FORMAT_CONFIRM_SKIP BACKUP_CONFIRM_SKIP REBOOT_SKIP SCAFFOLD_OVERWRITE_SKIP HARDWARE_OVERWRITE_SKIP PREFLIGHT_WARN_SKIP PROMPTS_SKIP AUTO_CONFIRM"

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

# When set, nds_cfg_get/set target this nameref name (feature AA) instead of CONFIG_DATA.
declare -g NDS_CFG_AA_NAME="${NDS_CFG_AA_NAME:-}"

nds_cfg_get() {
    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        # shellcheck disable=SC2178
        local -n _nds_cfg_aa_live="${NDS_CFG_AA_NAME}"
        echo "${_nds_cfg_aa_live[$1]:-${2:-}}"
        return 0
    fi
    echo "${CONFIG_DATA[$1]:-${2:-}}"
}

nds_cfg_set() {
    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        # shellcheck disable=SC2178
        local -n _nds_cfg_aa_live="${NDS_CFG_AA_NAME}"
        _nds_cfg_aa_live["$1"]="$2"
        return 0
    fi
    CONFIG_DATA["$1"]="$2"
}

nds_cfg_is() {
    [[ "$(nds_cfg_get "$1")" == "$2" ]]
}

nds_cfg_true() {
    nds_cfg_is "$1" true
}

# Full export: every config value. Used for the install backup bundle so a
# future run can reproduce the machine exactly.
nds_cfg_export_script() {
    local varname
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# Snapshot the seeded defaults so the concise export can tell what the user
# actually changed. Call after presets seed defaults, before env/menu edits.
nds_cfg_snapshot_defaults() {
    CONFIG_DEFAULTS=()
    local k
    for k in "${!CONFIG_DATA[@]}"; do
        CONFIG_DEFAULTS["$k"]="${CONFIG_DATA[$k]}"
    done
}

_settings_export_is_always() {
    local key="$1" a
    for a in $_NDS_EXPORT_ALWAYS; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_settings_export_is_when_set() {
    local key="$1" a
    for a in $_NDS_EXPORT_WHEN_SET; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_settings_export_is_hardware() {
    local key="$1" a
    for a in $_NDS_EXPORT_HARDWARE; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

# Whether a key belongs in the concise export: auto-detected essentials always,
# otherwise only when the user changed it from the seeded default.
_settings_export_is_skipped() {
    local key="$1" a
    for a in $_NDS_EXPORT_SKIP; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_settings_export_should_include() {
    local key="$1" cur="${CONFIG_DATA[$1]}"
    _settings_export_is_skipped "$key" && return 1
    if _settings_export_is_when_set "$key"; then
        [[ -n "$cur" ]]
        return
    fi
    if _settings_export_is_always "$key"; then
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
nds_cfg_export_modified() {
    local varname
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        _settings_export_should_include "$varname" || continue
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# Concise export as grouped sections — scoped declare -A blocks (preferred) plus
# legacy scalar exports for simple re-runs. Git URL maps included when set.
# Machine-specific keys, then menu skip flags (default false).
nds_cfg_export_grouped() {
    local varname
    local -a portable=() hardware=()
    local scope

    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        _settings_export_should_include "$varname" || continue
        if _settings_export_is_hardware "$varname"; then
            hardware+=("$varname")
        else
            portable+=("$varname")
        fi
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)

    echo "# Preferred: scoped arrays (save as a file, then:"
    echo "#   export NDS_SCOPED_CONFIG_FILE=/path/to/this-file"
    echo "#   # then start NDS — AAs cannot cross sudo without a file)"
    echo "#"

    if declare -f nds_cfg_export_scoped_block &>/dev/null; then
        nds_cfg_sync_store_to_scoped 2>/dev/null || true
        echo "# Configuration — portable (scoped):"
        for scope in FLAKE ACCESS REGION QUICK ENCRYPTION; do
            nds_cfg_export_scoped_block "$scope"
            echo ""
        done
        if [[ ${#hardware[@]} -gt 0 ]]; then
            echo "# This machine only — disk / boot / VM / network:"
            for scope in DISK BOOT NETWORK PLATFORM; do
                nds_cfg_export_scoped_block "$scope"
                echo ""
            done
        fi
        if declare -f nds_cfg_export_git_maps &>/dev/null; then
            echo "# Git per-repo access (URL-keyed):"
            nds_cfg_export_git_maps
        fi
    fi

    echo "# Legacy scalars (also accepted):"
    if [[ ${#portable[@]} -gt 0 ]]; then
        for varname in "${portable[@]}"; do
            echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
        done
    fi
    if [[ ${#hardware[@]} -gt 0 ]]; then
        [[ ${#portable[@]} -gt 0 ]] && echo ""
        for varname in "${hardware[@]}"; do
            echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
        done
    fi

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

nds_cfg_preset_enable() {
    PRESET_REGISTRY["$1"]="enabled"
}

nds_cfg_preset_disable() {
    [[ -n "${PRESET_REGISTRY[$1]:-}" ]] || return 0
    PRESET_REGISTRY["$1"]="disabled"
}

nds_cfg_preset_set_priority() {
    PRESET_META["${1}__priority"]="$2"
}

nds_cfg_preset_set_display() {
    PRESET_META["${1}__display"]="$2"
}

nds_cfg_preset_get_priority() {
    echo "${PRESET_META[${1}__priority]:-50}"
}

nds_cfg_preset_get_display() {
    local preset="$1"
    local display="${PRESET_META[${preset}__display]:-}"
    if [[ -z "$display" ]]; then
        display="$(echo "${preset^}" | tr '_' ' ')"
    fi
    echo "$display"
}

_nds_cfg_sort_presets() {
    local presets=("$@")
    [[ ${#presets[@]} -eq 0 ]] && return 0
    local sorted=() preset priority
    for preset in "${presets[@]}"; do
        priority=$(nds_cfg_preset_get_priority "$preset")
        sorted+=("${priority}:${preset}")
    done
    printf '%s\n' "${sorted[@]}" | sort -t: -k1,1n -k2,2 | cut -d: -f2
}

nds_cfg_preset_get_all_enabled() {
    local presets=() preset
    for preset in "${!PRESET_REGISTRY[@]}"; do
        [[ "${PRESET_REGISTRY[$preset]}" == "enabled" ]] && presets+=("$preset")
    done
    _nds_cfg_sort_presets "${presets[@]}"
}

nds_cfg_reset_for_action() {
    local bootstrap_dir="${1:?bootstrap dir}"
    local preset preset_dir preset_file
    preset_dir="$(nds_preset_dir "$bootstrap_dir")"
    for preset_file in "${preset_dir}/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        preset=$(basename "$preset_file" .sh)
        nds_cfg_preset_enable "$preset"
        unset "PRESET_META[${preset}__display]"
    done
    for preset in installFlake remoteAction; do
        nds_cfg_preset_disable "$preset"
        unset "PRESET_META[${preset}__display]"
        unset "PRESET_META[${preset}__priority]"
    done
}
