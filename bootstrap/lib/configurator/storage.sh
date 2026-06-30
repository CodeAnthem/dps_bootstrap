#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configurator - Storage Layer
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2026-06-30
# Description:   Data layer - registries and storage (no logic)
# Dependencies:  None (pure data layer)
# ==================================================================================================

# =============================================================================
# GLOBAL REGISTRIES
# =============================================================================

# Preset registry: preset_name → "enabled"|"disabled"
declare -gA PRESET_REGISTRY=()

# Preset metadata: preset__attribute → value
declare -gA PRESET_META=()

# Preset functions cache: preset__function_name → "true" (exists)
declare -gA PRESET_FUNCTIONS=()

# ConfigVar metadata: VARNAME__attribute → value
declare -gA VAR_META=()

# ConfigVar data: VARNAME → value
declare -gA CONFIG_DATA=()

# =============================================================================
# CONTEXT VARIABLES
# =============================================================================

# Current preset context (set during init)
declare -gx PRESET_CONTEXT=""

# Current validator context (set during validation)
declare -gx VALIDATOR_CONTEXT=""

# Cached validator options for current var
declare -gA VALIDATOR_OPTIONS=()

# =============================================================================
# PRESET OPERATIONS
# =============================================================================

nds_configurator_preset_enable() {
    PRESET_REGISTRY["$1"]="enabled"
}

nds_configurator_preset_disable() {
    PRESET_REGISTRY["$1"]="disabled"
}

_nds_configurator_preset_is_enabled() {
    [[ "${PRESET_REGISTRY[$1]:-}" == "enabled" ]]
}

# Sort presets by priority (ascending), then alphabetically
# Usage: _nds_configurator_sort_presets preset1 preset2 ...
# Returns: sorted preset names (one per line)
_nds_configurator_sort_presets() {
    local presets=("$@")
    [[ ${#presets[@]} -eq 0 ]] && return 0
    
    # Format: priority:preset_name
    local sorted=()
    for preset in "${presets[@]}"; do
        local priority
        priority=$(nds_configurator_preset_get_priority "$preset")
        sorted+=("${priority}:${preset}")
    done
    
    # Sort and extract preset names
    printf '%s\n' "${sorted[@]}" | sort -t: -k1,1n -k2,2 | cut -d: -f2
}

nds_configurator_preset_get_all_enabled() {
    local presets=()
    for preset in "${!PRESET_REGISTRY[@]}"; do
        if [[ "${PRESET_REGISTRY[$preset]}" == "enabled" ]]; then
            presets+=("$preset")
        fi
    done
    
    # Use dedicated sort function
    _nds_configurator_sort_presets "${presets[@]}"
}

nds_configurator_preset_set_priority() {
    PRESET_META["${1}__priority"]="$2"
}

nds_configurator_preset_get_priority() {
    echo "${PRESET_META[${1}__priority]:-50}"
}

nds_configurator_preset_set_display() {
    PRESET_META["${1}__display"]="$2"
}

nds_configurator_preset_get_display() {
    local preset="$1"
    local display="${PRESET_META[${preset}__display]:-}"
    # Auto-generate from preset name if not set
    if [[ -z "$display" ]]; then
        display="$(echo "${preset^}" | tr '_' ' ')"
    fi
    echo "$display"
}

# Reset preset enablement to bootstrap defaults before each action's action_config().
# Usage: nds_configurator_reset_for_action "bootstrap_dir"
nds_configurator_reset_for_action() {
    local bootstrap_dir="${1:?bootstrap dir}"
    local preset preset_file

    for preset_file in "${bootstrap_dir}/lib/configurator/presets/"*.sh; do
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

# Check if preset has cached function
_nds_configurator_preset_has_function() {
    [[ "${PRESET_FUNCTIONS[${1}__${2}]:-}" == "true" ]]
}

# =============================================================================
# CONFIGVAR DECLARATION
# =============================================================================

nds_configurator_var_declare() {
    local varname="$1"
    shift
    local preset="${PRESET_CONTEXT}"

    # Skip re-declare when switching actions in the same session
    if _nds_configurator_var_exists "$varname"; then
        return 0
    fi

    # Store preset ownership
    VAR_META["${varname}__preset"]="$preset"

    # Parse attributes
    for attr in "$@"; do
        local key="${attr%%=*}"
        local value="${attr#*=}"
        VAR_META["${varname}__${key}"]="$value"
    done

    # Set default
    CONFIG_DATA["$varname"]="${VAR_META[${varname}__default]:-}"
}

nds_configurator_var_modify() {
    local varname="$1" attribute="$2" value="$3"

    if ! _nds_configurator_var_exists "$varname"; then
        error "ConfigVar not found: $varname"
        return 1
    fi

    VAR_META["${varname}__${attribute}"]="$value"
}

nds_configurator_var_get_meta() {
    echo "${VAR_META[${1}__${2}]:-}"
}

_nds_configurator_var_exists() {
    [[ -n "${VAR_META[${1}__display]:-}" ]]
}

nds_configurator_var_list() {
    local preset="${1:-}"

    for key in "${!VAR_META[@]}"; do
        if [[ "$key" =~ ^(.+)__display$ ]]; then
            local var="${BASH_REMATCH[1]}"
            if [[ -z "$preset" ]] || [[ "${VAR_META[${var}__preset]}" == "$preset" ]]; then
                echo "$var"
            fi
        fi
    done
}

# =============================================================================
# CONFIG DATA ACCESS
# =============================================================================

nds_configurator_config_set() {
    CONFIG_DATA["$1"]="$2"
}

nds_configurator_config_get() {
    echo "${CONFIG_DATA[$1]:-${2:-}}"
}

# Legacy preset-scoped getter — preset name ignored; vars are flat in CONFIG_DATA.
# Usage: nds_config_get "disk" "DISK_TARGET"
nds_config_get() {
    nds_configurator_config_get "$2"
}

# Get config value with env variable fallback (checks NDS_<varname>)
# Usage: nds_configurator_config_get_env varname [default]
nds_configurator_config_get_env() {
    local varname="$1"
    local default="${2:-}"
    local env_var="NDS_${varname}"
    
    # Check env variable first
    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
    else
        echo "${CONFIG_DATA[$varname]:-$default}"
    fi
}

nds_configurator_config_export_script() {
    for varname in "${!CONFIG_DATA[@]}"; do
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done
}

# Print configuration export before install confirmation (copy optional).
nds_configurator_print_config_backup() {
    local line

    section_header "Configuration export"
    nds_ui_b "If you plan to finish installation, you do not need to copy anything here."
    nds_ui_b "NDS includes this configuration in the install backup zip when installation completes."
    nds_ui_b ""
    while IFS= read -r line; do
        nds_ui_i "$line"
    done < <(nds_configurator_config_export_script)
    nds_ui_b ""
}

# Continue to install review — does not start partitioning yet.
nds_configurator_confirm_config_saved() {
    nds_askUserToProceed "Continue to installation review" || return 1
    return 0
}

# =============================================================================
# VALIDATOR CONTEXT (Internal)
# =============================================================================

_nds_configurator_set_validator_context() {
    local varname="$1"
    VALIDATOR_CONTEXT="$varname"

    # Cache all options
    VALIDATOR_OPTIONS=()
    for key in "${!VAR_META[@]}"; do
        if [[ "$key" =~ ^${varname}__(.+)$ ]]; then
            local attr="${BASH_REMATCH[1]}"
            VALIDATOR_OPTIONS["$attr"]="${VAR_META[$key]}"
        fi
    done
}

_nds_configurator_clear_validator_context() {
    VALIDATOR_CONTEXT=""
    VALIDATOR_OPTIONS=()
}

_nds_configurator_get_validator_opt() {
    echo "${VALIDATOR_OPTIONS[${1}]:-${2:-}}"
}
