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
readonly ACTION_TARGET_NAME="setup.sh"         # entrypoint file for actions
declare -ga ACTION_NAMES=()                       # array of discovered action names
declare -gA ACTION_DATA=()                        # associative array of action metadata
declare -g ACTION_CURRENT_NAME=""                # current action name
declare -g ACTION_CURRENT_DESCRIPTION=""         # current action description
declare -g ACTION_CURRENT_PATH=""                # current action path

# ----------------------------------------------------------------------------------
# Validate and register a single action
# ----------------------------------------------------------------------------------
_nds_action_register_and_validate() {
    local actionName="$1"
    local actionPath="$2"
    local actionFile="${actionPath}/${ACTION_TARGET_NAME}"

    # Check if target file exists
    if [[ ! -f "$actionFile" ]]; then
        debug "Action '$actionName': Missing ${ACTION_TARGET_NAME}"
        return 1
    fi

    # Check for required functions (without sourcing)
    if ! grep -Eq '^action_config[[:space:]]*\(\)' "$actionFile"; then
        debug "Action '$actionName': Missing action_config() function"
        return 1
    fi

    if ! grep -Eq '^action_setup[[:space:]]*\(\)' "$actionFile"; then
        debug "Action '$actionName': Missing action_setup() function"
        return 1
    fi

    # Extract and validate description
    local description
    description=$(grep -m1 "^# Description:" "$actionFile" | cut -d':' -f2- | xargs)

    # Fallback: empty description -> invalid
    if [[ -z "$description" ]]; then
        debug "Action '$actionName': Missing description in header"
        return 1
    fi
    # Register action
    ACTION_NAMES+=("$actionName")
    ACTION_DATA["${actionName}::path"]="$actionPath"
    ACTION_DATA["${actionName}::description"]="$description"

    debug "Validated action: $actionName"
    return 0
}

# ----------------------------------------------------------------------------------
# Select an action by name
# ----------------------------------------------------------------------------------
_nds_action_select() {
    local actionName="$1"

    if [[ -n "${ACTION_DATA[${actionName}::path]:-}" ]]; then
        ACTION_CURRENT_NAME="$actionName"
        ACTION_CURRENT_PATH="${ACTION_DATA[${actionName}::path]}"
        ACTION_CURRENT_DESCRIPTION="${ACTION_DATA[${actionName}::description]}"
        return 0
    fi

    warn "Action '$actionName' not found"
    return 1
}

# ----------------------------------------------------------------------------------
# Discover all valid actions within directory
# ----------------------------------------------------------------------------------
# Flexible calling conventions:
#   nds_action_discover <dir> <dev1> <dev2> ... <allowFlag?>
#   nds_action_discover <dir> <allowFlag> <dev1> <dev2> ...
# allowFlag is "true" or "false" and may be supplied as the last arg or the first after dir.
nds_action_discover() {
    local dirActions="$1"
    shift || true

    # Gather args into array for easier handling
    local args=("$@")
    local argCount=${#args[@]}
    local allowDevActions="false"
    local -a devActions=()

    # Determine allowDevActions if present as first or last positional argument
    if (( argCount > 0 )); then
        # If first arg is explicit true/false -> treat as allow flag, remainder are devActions
        if [[ "${args[0]}" == "true" || "${args[0]}" == "false" ]]; then
            allowDevActions="${args[0]}"
            if (( argCount > 1 )); then
                devActions=("${args[@]:1}")
            fi
        # Else if last arg is explicit true/false -> use it as allow flag, rest are devActions
        elif [[ "${args[$((argCount-1))]}" == "true" || "${args[$((argCount-1))]}" == "false" ]]; then
            allowDevActions="${args[$((argCount-1))]}"
            if (( argCount > 1 )); then
                devActions=("${args[@]:0:argCount-1}")
            fi
        else
            # No explicit allow flag -> treat all remaining args as devActions
            devActions=("${args[@]}")
        fi
    fi

    # Validate directory
    if [[ ! -d "$dirActions" ]]; then
        error "Actions directory not found: $dirActions"
        return 1
    fi

    # Validate allowDevActions value
    if [[ "$allowDevActions" != "true" && "$allowDevActions" != "false" ]]; then
        error "Invalid allowDevActions parameter: $allowDevActions | expected true or false"
        return 1
    fi

    # Build lookup map for dev actions (faster membership check), only if provided
    declare -A devActionMap=()
    if (( ${#devActions[@]} > 0 )); then
        for da in "${devActions[@]}"; do
            devActionMap["$da"]=1
        done
    else
        debug "No dev actions provided (devActionMap will be empty)"
    fi

    local actionFolder actionName validationOk=false
    for actionFolder in "$dirActions"/*/; do
        [[ -d "$actionFolder" ]] || continue
        actionName=$(basename "$actionFolder")

        # Skip dev-only actions unless explicitly allowed
        if [[ "$allowDevActions" != "true" && -n "${devActionMap[$actionName]:-}" ]]; then
            debug "Skipping dev action: $actionName (dev actions not allowed)"
            continue
        fi

        if _nds_action_register_and_validate "$actionName" "$actionFolder"; then
            validationOk=true
        else
            debug "Skipping invalid action: $actionName"
        fi
    done

    if [[ "${#ACTION_NAMES[@]}" -eq 0 || "$validationOk" = false ]]; then
        error "No valid actions found in $dirActions"
        return 1
    fi

    info "Discovered ${#ACTION_NAMES[@]} valid actions"
    return 0
}

# ----------------------------------------------------------------------------------
# Automatically select an action or display a selection menu
# ----------------------------------------------------------------------------------
nds_action_autoSelectOrMenu() {
    local autoSelection="${1:-}"

    new_section
    section_header "Choose Bootstrap Action"

    # Auto-selection
    if [[ -n "$autoSelection" ]]; then
        if _nds_action_select "$autoSelection"; then
            info "Auto selected action: $autoSelection"
            return 0
        else
            error "Auto selection failed for action: $autoSelection"
        fi
    fi

    # Manual selection menu
    console "  0) Abort - Exit the script"
    local i=1 actionName
    for actionName in "${ACTION_NAMES[@]}"; do
        console "  $i) $actionName - ${ACTION_DATA[${actionName}::description]}"
        ((i++))
    done

    local choice maxChoice="${#ACTION_NAMES[@]}"
    while true; do
        read -rsn 1 -p "    -> Select action [0-${maxChoice}]: " choice < /dev/tty

        case "$choice" in
            0)
                console "Operation aborted"
                exit 130
                ;;
            ''|*[!0-9]*)
                console "Invalid input. Choose 0-${maxChoice}"
                ;;
            *)
                if (( choice >= 1 && choice <= maxChoice )); then
                    local selectedAction="${ACTION_NAMES[$((choice - 1))]}"
                    if _nds_action_select "$selectedAction"; then
                        console "$selectedAction"
                        return 0
                    fi
                else
                    console "Invalid selection. Choose 0-${maxChoice}"
                fi
                ;;
        esac
    done
}

# ----------------------------------------------------------------------------------
# Execute the currently selected action
# ----------------------------------------------------------------------------------
nds_action_execute() {
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

    pass "Action completed: $ACTION_CURRENT_NAME"
}
