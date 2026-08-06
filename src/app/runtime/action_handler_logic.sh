#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action handler (select, configure, execute)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-05
# Description:   Action selection, feature AA bridge, presets, execution
# ==================================================================================================

# Description: Select action from NDS_ACTION when set to a discovered action name.
# Returns:
# - 0 when NDS_ACTION matched, 1 when unset or invalid
nds_actions_select_from_env() {
    local wanted="${NDS_ACTION:-}"
    local name

    [[ -n "$wanted" ]] || return 1

    for name in "${NDS_ACTION_NAMES[@]}"; do
        if [[ "$name" == "$wanted" ]]; then
            NDS_CURRENT_ACTION="$name"
            log "Action selected via NDS_ACTION=${wanted}"
            return 0
        fi
    done

    error "NDS_ACTION=${wanted} is not valid (available: ${NDS_ACTION_NAMES[*]})"
    return 1
}

nds_actions_select() {
    if nds_actions_select_from_env; then
        return 0
    fi

    # Invalid NDS_ACTION already reported by select_from_env when set but unmatched.
    if [[ -n "${NDS_ACTION:-}" ]]; then
        return 1
    fi

    nds_mode_resolve || return 1
    if nds_mode_is_unattended; then
        error "Unattended mode requires a valid NDS_ACTION (available: ${NDS_ACTION_NAMES[*]})"
        return 1
    fi

    nds_app_ui_select_action
}

_app_action_configure_presets() {
    local _preset _path _bundled=()

    if declare -f action_presets &>/dev/null; then
        while IFS= read -r _preset; do
            [[ -n "$_preset" ]] && _bundled+=("$_preset")
        done < <(action_presets)
        nds_preset_enable_bundle "$SCRIPT_DIR" "${_bundled[@]}" || return 1
    else
        nds_cfg_reset_for_action "$SCRIPT_DIR" || return 1
    fi

    if declare -f action_config &>/dev/null; then
        action_config
    fi

    if declare -f action_presets_paths &>/dev/null; then
        while IFS= read -r _path; do
            [[ -n "$_path" ]] || continue
            if [[ -d "$_path" ]]; then
                nds_preset_load_dir "$_path" || return 1
            elif [[ -f "$_path" ]]; then
                nds_preset_load_file "$_path" || return 1
            fi
        done < <(action_presets_paths)
    fi

    if [[ -n "${NDS_PRESET_EXTRA_DIR:-}" && -d "$NDS_PRESET_EXTRA_DIR" ]]; then
        nds_preset_load_dir "$NDS_PRESET_EXTRA_DIR" || return 1
    fi

    if declare -f action_presets_extend &>/dev/null; then
        action_presets_extend || return 1
    fi

    nds_cfg_seed_defaults
    return 0
}

# Description: Call feature entry as fn(mode, cfg_aa); merge AA back to store.
# Optional extra args: KEY=value overrides into the AA before the call.
nds_action_call_feature() {
    local fn="$1"
    shift
    local -A cfg=()
    local mode pair

    declare -f "$fn" &>/dev/null || {
        error "Feature entry not found: $fn"
        return 1
    }

    nds_mode_resolve || true
    mode="${NDS_MODE:-interactive}"
    nds_cfg_aa_from_store cfg
    for pair in "$@"; do
        [[ "$pair" == *=* ]] || continue
        cfg["${pair%%=*}"]="${pair#*=}"
    done

    "$fn" "$mode" cfg || return $?
    nds_cfg_aa_to_store cfg
    if declare -f nds_cfg_sync_store_to_scoped &>/dev/null; then
        nds_cfg_sync_store_to_scoped || true
    fi
    return 0
}

nds_actions_execute() {
    local action_name="$1"
    local action_path="${NDS_ACTION_DATA[${action_name}_path]}"
    local setup_script="${action_path}setup.sh"
    local rc=0

    export NDS_CURRENT_ACTION="$action_name"
    [[ -f "$setup_script" ]] || { error "Setup script not found: $setup_script"; return 1; }

    info "Loading $action_name action..."
    nds_import_file "$setup_script" || { error "Failed to import action"; return 1; }

    declare -f action_presets &>/dev/null || declare -f action_config &>/dev/null || {
        error "action_presets() or action_config() required"; return 1; }

    nds_framework_prepare_action_runtime || {
        error "Failed to prepare framework runtime for action: $action_name"
        return 1
    }

    info "Configuring $action_name..."
    _app_action_configure_presets || return 1

    nds_action_run_preview || rc=$?
    [[ "$rc" -ne 0 ]] && return "$rc"

    if declare -f action_on_accept &>/dev/null; then
        action_on_accept || return $?
    fi

    info "Executing $action_name..."
    action_setup || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        [[ "$rc" -eq "$NDS_ACTION_BACK" ]] && return "$NDS_ACTION_BACK"
        error "Action setup failed for: $action_name"
        return "$rc"
    fi
    success "Action completed: $action_name"
    return 0
}

nds_actions_main() {
    local rc=0
    while true; do
        NDS_CURRENT_ACTION=""
        nds_actions_select || return 1
        rc=0
        nds_actions_execute "$NDS_CURRENT_ACTION" || rc=$?
        [[ "$rc" -eq "$NDS_ACTION_BACK" ]] && {
            [[ -n "${NDS_ACTION:-}" ]] && {
                error "Cannot go back — NDS_ACTION is set to ${NDS_ACTION}"
                return 1
            }
            NDS_CURRENT_ACTION=""
            continue
        }
        [[ "$rc" -ne 0 ]] && return "$rc"
        break
    done
    return 0
}
