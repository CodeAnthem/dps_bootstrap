#!/usr/bin/env bash
# ==================================================================================================
# NDS - Core action workflow
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Discover, preview, configure presets, execute actions
# ==================================================================================================

declare -ga ACTION_NAMES=()
declare -gA ACTION_DATA=()
declare -g current_action=""
declare -g ACTIONS_DIR=""

_nds_validate_action() {
    local action_name="$1"
    local action_path="$2"
    local setup_script="${action_path}/setup.sh"

    [[ -f "$setup_script" ]] || { debug "Action '$action_name': Missing setup.sh"; return 1; }
    grep -qE "^action_(config|presets)\(\)" "$setup_script" || {
        debug "Action '$action_name': Missing action_presets() or action_config()"; return 1; }
    grep -q "^action_preview()" "$setup_script" || {
        debug "Action '$action_name': Missing action_preview()"; return 1; }
    grep -q "^action_setup()" "$setup_script" || {
        debug "Action '$action_name': Missing action_setup()"; return 1; }

    local description
    description=$(head -n 20 "$setup_script" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null)
    [[ -n "$description" ]] || { debug "Action '$action_name': Missing description"; return 1; }
    return 0
}

nds_actions_discover() {
    local actions_dir="${1:?actions dir}"
    ACTIONS_DIR="$actions_dir"
    ACTION_NAMES=()

    [[ -d "$ACTIONS_DIR" ]] || { error "Actions directory not found: $ACTIONS_DIR"; return 1; }

    local action_dir action_name description
    for action_dir in "$ACTIONS_DIR"/*/; do
        [[ -d "$action_dir" ]] || continue
        action_name=$(basename "$action_dir")
        [[ "$action_name" == "test" && "${NDS_TEST:-false}" != "true" ]] && continue
        _nds_validate_action "$action_name" "$action_dir" || { warn "Skipping invalid action: $action_name"; continue; }
        description=$(head -n 20 "${action_dir}setup.sh" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//')
        ACTION_NAMES+=("$action_name")
        ACTION_DATA["${action_name}_path"]="$action_dir"
        ACTION_DATA["${action_name}_description"]="$description"
    done

    [[ ${#ACTION_NAMES[@]} -gt 0 ]] || { error "No valid actions in $ACTIONS_DIR"; return 1; }
    debug "Discovered ${#ACTION_NAMES[@]} actions"
    return 0
}

nds_actions_select() {
    section_header "Choose an action"
    nds_ui_b ""
    nds_ui_choice_row "0" "Abort" "Exit the script"
    nds_ui_b ""

    local i=1 action_name
    for action_name in "${ACTION_NAMES[@]}"; do
        nds_ui_choice_row "$i" "$action_name" "${ACTION_DATA[${action_name}_description]}"
        ((i++))
    done
    nds_ui_b ""

    local choice max_choice="${#ACTION_NAMES[@]}"
    while true; do
        read -rsn1 -p "${NDS_UI_INDENT_B}Select action to preview [0-$max_choice]: " choice < /dev/tty
        echo >&2
        [[ "$choice" == "0" ]] && { nds_ui_b "Operation aborted"; exit 130; }
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_choice" ]]; then
            current_action="${ACTION_NAMES[$((choice-1))]}"
            return 0
        fi
        nds_ui_b "Invalid selection. Choose 0-$max_choice"
    done
}

_nds_action_configure_presets() {
    local _preset _path _bundled=()

    if declare -f action_presets &>/dev/null; then
        while IFS= read -r _preset; do
            [[ -n "$_preset" ]] && _bundled+=("$_preset")
        done < <(action_presets)
        nds_preset_enable_bundle "$SCRIPT_DIR" "${_bundled[@]}" || return 1
    else
        nds_configurator_reset_for_action "$SCRIPT_DIR" || return 1
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

    nds_config_seed_defaults
    return 0
}

_nds_run_action_preview() {
    declare -f action_preview &>/dev/null || { error "action_preview() not found"; return 1; }
    section_header "Install preview"
    action_preview
    nds_ui_b "Press Y to continue, B to go back to the action menu."
    nds_ui_b ""
    nds_askUserContinue "Proceed with this action?"
    local prc=$?
    case "$prc" in
        0) return 0 ;;
        2) return "$NDS_ACTION_BACK" ;;
        *) return 130 ;;
    esac
}

nds_actions_execute() {
    local action_name="$1"
    local action_path="${ACTION_DATA[${action_name}_path]}"
    local setup_script="${action_path}setup.sh"
    local rc=0

    export NDS_CURRENT_ACTION="$action_name"
    [[ -f "$setup_script" ]] || { error "Setup script not found: $setup_script"; return 1; }

    info "Loading $action_name action..."
    nds_import_file "$setup_script" || { error "Failed to import action"; return 1; }

    declare -f action_presets &>/dev/null || declare -f action_config &>/dev/null || {
        error "action_presets() or action_config() required"; return 1; }

    info "Configuring $action_name..."
    _nds_action_configure_presets || return 1

    _nds_run_action_preview || rc=$?
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
        nds_actions_select
        rc=0
        nds_actions_execute "$current_action" || rc=$?
        [[ "$rc" -eq "$NDS_ACTION_BACK" ]] && { NDS_CURRENT_ACTION=""; continue; }
        [[ "$rc" -ne 0 ]] && return "$rc"
        break
    done
    return 0
}
