#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Handles actions workflow
# Feature:       Action discovery, validation, registration, selection and execution
# ==================================================================================================

# ----------------------------------------------------------------------------------
# Globals
# ----------------------------------------------------------------------------------
declare -g ACTION_TARGET_NAME="setup.sh"         # entrypoint file for actions
declare -a ACTION_NAMES=()                       # array of discovered action names
declare -A ACTION_DATA=()                        # associative array of action metadata
declare -g ACTION_CURRENT_NAME=""                # current action name
declare -g ACTION_CURRENT_DESCRIPTION=""         # current action description
declare -g ACTION_CURRENT_PATH=""                # current action path

# ----------------------------------------------------------------------------------
# Validate and register a single action
# ----------------------------------------------------------------------------------
_nds_action_register_and_validate() {
    local _action_name="$1"
    local _action_path="$2"
    local _action_file="${_action_path}/${ACTION_TARGET_NAME}"

    # Check if target file exists
    if [[ ! -f "$_action_file" ]]; then
        debug "Action '$_action_name': Missing ${ACTION_TARGET_NAME}"
        return 1
    fi

    # Check for required functions (without sourcing)
    if ! grep -Eq '^action_config[[:space:]]*\(\)' "$_action_file"; then
        debug "Action '$_action_name': Missing action_config() function"
        return 1
    fi

    if ! grep -Eq '^action_setup[[:space:]]*\(\)' "$_action_file"; then
        debug "Action '$_action_name': Missing action_setup() function"
        return 1
    fi

    # Extract and validate description
    local _description
    _description=$(grep -m1 "^# Description:" "$_action_file" | cut -d':' -f2- | xargs)

    # _description=$(head -n 20 "$_action_file" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null)
    if [[ -z "$_description" ]]; then
        debug "Action '$_action_name': Missing description in header"
        return 1
    fi

    # Register action
    ACTION_NAMES+=("$_action_name")
    ACTION_DATA["${_action_name}::_path"]="$_action_path"
    ACTION_DATA["${_action_name}::_description"]="$_description"

    debug "Validated action: $_action_name"
}

# ----------------------------------------------------------------------------------
# Select an action by name
# ----------------------------------------------------------------------------------
_nds_action_select() {
    local _action_name="$1"

    if [[ -n "${ACTION_DATA[${_action_name}::_path]}" ]]; then
        ACTION_CURRENT_NAME="$_action_name"
        ACTION_CURRENT_PATH="${ACTION_DATA[${_action_name}::_path]}"
        ACTION_CURRENT_DESCRIPTION="${ACTION_DATA[${_action_name}::_description]}"
        return 0
    fi

    error "Action '$_action_name' not found"
    return 1
}

# ----------------------------------------------------------------------------------
# Discover all valid actions within directory
# ----------------------------------------------------------------------------------
_nds_action_discover() {
    local _dir_actions="$1"
    local -a _dev_actions=("${!2}") # expect array name passed with "${_dev_actions[@]}"
    local _allow_devActions="${3:-false}"

    # Validate inputs
    if [[ ! -d "$_dir_actions" ]]; then
        error "Actions directory not found: $_dir_actions"
        return 1
    fi
    if [[ "${#_dev_actions[@]}" -eq 0 ]]; then
        error "Dev actions list is empty"
        return 1
    fi
    if [[ "$_allow_devActions" != "true" && "$_allow_devActions" != "false" ]]; then
        error "Invalid _allow_devActions parameter: $_allow_devActions | expected true or false"
        return 1
    fi

    # Build lookup map for dev actions (faster membership check)
    declare -A _dev_action_map=()
    for _da in "${_dev_actions[@]}"; do
        _dev_action_map["$_da"]=1
    done

    local _actionFolder _action_name
    for _actionFolder in "$_dir_actions"/*/; do
        [[ -d "$_actionFolder" ]] || continue
        _action_name=$(basename "$_actionFolder")

        # Skip dev-only actions unless explicitly allowed
        if [[ "$_allow_devActions" != "true" && -n "${_dev_action_map[$_action_name]}" ]]; then
            debug "Skipping dev action: $_action_name (dev actions not allowed)"
            continue
        fi

        _nds_action_register_and_validate "$_action_name" "$_actionFolder"
    done

    if [[ ${#ACTION_NAMES[@]} -eq 0 ]]; then
        error "No valid actions found in $_dir_actions"
        return 1
    fi

    info "Discovered ${#ACTION_NAMES[@]} valid actions"
    return 0
}

# ----------------------------------------------------------------------------------
# Automatically select an action or display a selection menu
# ----------------------------------------------------------------------------------
_nds_action_autoSelectOrMenu() {
    local _autoSelection="${1:-}"

    new_section
    section_header "Choose Bootstrap Action"

    # Auto-selection
    if [[ -n "$_autoSelection" ]]; then
        if _nds_action_select "$_autoSelection"; then
            info "Auto selected action: $_autoSelection"
            return 0
        else
            warn "Auto selection failed for action: $_autoSelection"
            new_line
        fi
    fi

    # Manual selection menu
    console "  0) Abort - Exit the script"
    local i=1 _action_name
    for _action_name in "${ACTION_NAMES[@]}"; do
        console "  $i) $_action_name - ${ACTION_DATA[${_action_name}::_description]}"
        ((i++))
    done

    local _choice _max_choice="${#ACTION_NAMES[@]}"
    while true; do
        read -rp "     -> Select action [0-${_max_choice}]: " _choice < /dev/tty

        case "$_choice" in
            0)
                console "Operation aborted"
                exit 130
                ;;
            ''|*[!0-9]*)
                console "Invalid input. Choose 0-${_max_choice}"
                ;;
            *)
                if (( _choice >= 1 && _choice <= _max_choice )); then
                    local _selected_action="${ACTION_NAMES[$((_choice - 1))]}"
                    if _nds_action_select "$_selected_action"; then
                        console "$_selected_action"
                        return 0
                    fi
                else
                    console "Invalid selection. Choose 0-${_max_choice}"
                fi
                ;;
        esac
    done
}

# ----------------------------------------------------------------------------------
# Execute the currently selected action
# ----------------------------------------------------------------------------------
_nds_action_execute() {
    info "Loading $ACTION_CURRENT_NAME action..."
    if ! nds_import_file "$ACTION_CURRENT_PATH/$ACTION_TARGET_NAME"; then
        fatal "Failed to import action setup script"
    fi

    if declare -f action_config &>/dev/null; then
        info "Configuring $ACTION_CURRENT_NAME..."
        action_config # TODO: add hook here
    else
        fatal "action_config() not found in $ACTION_TARGET_NAME"
    fi

    info "Executing $ACTION_CURRENT_NAME..."
    section_title "Action: $ACTION_CURRENT_NAME"
    if ! action_setup; then # TODO: add hook here
        fatal "Action setup failed for: $ACTION_CURRENT_NAME"
    fi

    success "Action completed: $ACTION_CURRENT_NAME"
}
