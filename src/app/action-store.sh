#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action store (discovery and registry)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Discover, validate, and store available actions (data layer, no UI)
# ==================================================================================================

declare -ga ACTION_NAMES=()
declare -gA ACTION_DATA=()
declare -g ACTIONS_DIR=""

_app_validate_action() {
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

# Description: Scan the actions directory, validate each action, populate ACTION_NAMES and ACTION_DATA.
# Arguments:
# - actions_dir: <String> Path to the actions directory
# Returns:
# - <Bool> 0 when at least one valid action is found
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
        _app_validate_action "$action_name" "$action_dir" || { warn "Skipping invalid action: $action_name"; continue; }
        description=$(head -n 20 "${action_dir}setup.sh" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//')
        ACTION_NAMES+=("$action_name")
        ACTION_DATA["${action_name}_path"]="$action_dir"
        ACTION_DATA["${action_name}_description"]="$description"
    done

    [[ ${#ACTION_NAMES[@]} -gt 0 ]] || { error "No valid actions in $ACTIONS_DIR"; return 1; }
    debug "Discovered ${#ACTION_NAMES[@]} actions"
    return 0
}
