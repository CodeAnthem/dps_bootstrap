#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-29
# Description:   Entry point selector for DPS Bootstrap - dynamically discovers and executes actions
# Feature:       Action discovery, library management, root validation, cleanup handling
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

# =============================================================================
# SCRIPT VARIABLES
# =============================================================================
# Meta Data
readonly SCRIPT_VERSION="4.0.0"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper)"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"

# Declare global associative array for hook function names
declare -gA DPS_HOOK_FUCNTIONS=(
    ["exit_msg"]="hook_exit_msg" # Message to display on exit
    ["exit_cleanup"]="hook_exit_cleanup" # Cleanup to perform on exit
)

# =============================================================================
# IMPORT LIBRARIES
# =============================================================================
nds_source_dir() {
    local directory recursive item basename

    # Validate parameters
    directory="$1"
    [[ -d "$directory" ]] || {
        echo "Error: Directory not found: $directory" >&2
        return 1
    }
    
    recursive="${2:-false}"
    [[ "$recursive" == "true" || "$recursive" == "false" ]] || {
        echo "Error: Invalid recursive parameter: $recursive" >&2
        return 1
    }

    for item in "$directory"/*; do
        [[ -e "$item" ]] || continue # Skip if no match (e.g. empty dir)

        # Skip files/folders starting with underscore
        basename=$(basename "$item")
        [[ "${basename:0:1}" == "_" ]] && continue

        # If directory, recurse if enabled
        if [[ -d "$item" ]]; then
            if [[ "$recursive" == "true" ]]; then
                nds_source_dir "$item" "$recursive" || return 1
            fi
            continue
        fi

        # Only source .sh files
        if [[ "${basename: -3}" == ".sh" ]]; then
            # shellcheck disable=SC1090
            if ! source "$item"; then
                echo "Error: Failed to source: $item" >&2
                return 1
            fi
        fi
    done
}

# Load libraries
nds_source_dir "${SCRIPT_DIR}/lib" false || exit 1

# Display script header
section_title "$SCRIPT_NAME v$SCRIPT_VERSION"
success "Bootstrapper 'NDS' libraries loaded"


# =============================================================================
# HOOK FUNCTIONS
# =============================================================================
# shellcheck disable=SC2329 # Hook is called dynamically
_nds_callHook() {
    local hookName="$1"
    shift
    local hookFunction="${DPS_HOOK_FUCNTIONS[$hookName]}"

    # Check if hook is valid
    if [[ -z "$hookFunction" ]]; then
        error "Hook '$hookName' not found"
        return 1
    fi

    # Check and call if hook function exists
    if declare -f "$hookFunction" &>/dev/null; then
        "$hookFunction" "$@"
        return 0
    fi

    # Hook not active
    return 1
}


# =============================================================================
# ROOT CHECK
# =============================================================================
# Root privilege check with sudo fallback
if [[ $EUID -ne 0 ]]; then
    new_section
    section_header "Root Privilege Required"
    warn "This script requires root privileges."
    info "Attempting to restart with sudo..."
    
    # Preserve DPS_* environment variables through sudo
    dps_vars=()
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^DPS_ ]]; then
            dps_vars+=("$name=$value")
        fi
    done < <(env)
    
    # Restart with sudo, preserving DPS_* and DEBUG variables
    if [[ ${#dps_vars[@]} -gt 0 ]]; then
        exec sudo "${dps_vars[@]}" DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "$@"
    else
        exec sudo bash "${BASH_SOURCE[0]}" "$@"
    fi
else
    success "Root privileges confirmed"
fi


# =============================================================================
# RUNTIME DIRECTORY
# =============================================================================
# Setup runtime directory - declare and assign separately
setupRuntimeDir() {
    local timestamp=""
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    [[ -z "$timestamp" ]] && return 1
    RUNTIME_DIR="/tmp/dps_${timestamp}_$$"

    # Create runtime directory
    mkdir -p "$RUNTIME_DIR" || return 1
    chmod 700 "$RUNTIME_DIR" || return 1
    return 0
}

# shellcheck disable=SC2329
purgeRuntimeDir() {
    if [[ -d "${RUNTIME_DIR:-}" ]]; then
        if rm -rf "$RUNTIME_DIR"; then
            success " > Runtime directory cleaned up: $RUNTIME_DIR"
        else
            error " > Failed to clean up runtime directory: $RUNTIME_DIR"
        fi
    fi

    # shellcheck disable=SC2010
    ls -l /tmp/ | grep -i "dps" # TODO: Remove after debugging
}


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================
declare -g exit_message=""
crash() {
    exit_message="$1"
    exit 200
}

# shellcheck disable=SC2329
_main_stopHandler() {
    local exit_code=$?

    # Get custom exit message if exists
    local exit_msg=""
    exit_msg=$(_nds_callHook "exit_msg" "$exit_code")
    if [[ -n "$exit_msg" ]]; then
        console "$exit_msg"
    else
        case "${exit_code}" in
            0)
                success "Script completed successfully"
            ;;
            130)
                warn "Script aborted by user"
            ;;
            200)
                fatal "${exit_message:-}"
            ;;
            *)
                warn "Script failed with exit code: $exit_code"
            ;;
        esac
        
    fi

    # Bootstrapper cleanup
    info "Cleaning up session"
    purgeRuntimeDir
    
    # Call cleanup hook
    _nds_callHook "exit_cleanup" "$exit_code"
}


# =============================================================================
# ACTION DISCOVERY
# =============================================================================

# Validate action structure
_nds_validate_action() {
    local action_name="$1"
    local action_path="$2"
    local setup_script="${action_path}/setup.sh"
    
    # Check setup.sh exists
    if [[ ! -f "$setup_script" ]]; then
        debug "Action '$action_name': Missing setup.sh"
        return 1
    fi
    
    # Check for required functions (without sourcing)
    if ! grep -q "^action_config()" "$setup_script"; then
        debug "Action '$action_name': Missing action_config() function"
        return 1
    fi
    
    if ! grep -q "^action_setup()" "$setup_script"; then
        debug "Action '$action_name': Missing action_setup() function"
        return 1
    fi
    
    # Check for description in header
    local description
    description=$(head -n 20 "$setup_script" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null)
    if [[ -z "$description" ]]; then
        debug "Action '$action_name': Missing description in header"
        return 1
    fi
    
    return 0
}

_nds_discover_actions() {
    if [[ ! -d "$ACTIONS_DIR" ]]; then
        error "Actions directory not found: $ACTIONS_DIR"
        return 1
    fi
    
    for action_dir in "$ACTIONS_DIR"/*/; do
        [[ -d "$action_dir" ]] || continue
        
        local action_name
        action_name=$(basename "$action_dir")
        
        # Skip test action unless DPS_TEST=true
        if [[ "$action_name" == "test" && "${DPS_TEST:-false}" != "true" ]]; then
            debug "Skipping test action (DPS_TEST not set)"
            continue
        fi
        
        # Validate action structure
        if ! _nds_validate_action "$action_name" "$action_dir"; then
            warn "Skipping invalid action: $action_name"
            continue
        fi
        
        # Extract metadata
        local description
        description=$(head -n 20 "${action_dir}setup.sh" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//')
        
        # Store in arrays
        ACTION_NAMES+=("$action_name")
        ACTION_DATA["${action_name}_path"]="$action_dir"
        ACTION_DATA["${action_name}_description"]="$description"
        
        debug "Validated action: $action_name"
    done
    
    if [[ ${#ACTION_NAMES[@]} -eq 0 ]]; then
        error "No valid actions found in $ACTIONS_DIR"
        return 1
    fi
    
    info "Discovered ${#ACTION_NAMES[@]} valid actions"
    return 0
}

# =============================================================================
# ACTION SELECTION
# =============================================================================
_nds_select_action() {
    new_section
    section_header "Choose Bootstrap Action"
    
    console "  0) Abort - Exit the script"
    
    local i=1
    for action_name in "${ACTION_NAMES[@]}"; do
        local description="${ACTION_DATA[${action_name}_description]}"
        console "  $i) $action_name - $description"
        ((i++))
    done
    
    local choice max_choice
    max_choice="${#ACTION_NAMES[@]}"
    
    # Loop until valid choice
    while true; do
        read -rsn1 -p "     -> Select action [0-$max_choice]: " choice < /dev/tty
        echo
        
        # Handle abort
        if [[ "$choice" == "0" ]]; then
            console "Operation aborted"
            exit 130
        fi
        
        # Validate choice is a number and in range
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_choice" ]]; then
            local selected_action="${ACTION_NAMES[$((choice-1))]}"
            console "$selected_action"
            newline
            return 0
        fi
        
        # Invalid selection
        console "Invalid selection. Choose 0-$max_choice"
    done
}

# =============================================================================
# ACTION EXECUTION
# =============================================================================
_nds_execute_action() {
    local action_name="$1"
    local action_path="${ACTION_DATA[${action_name}_path]}"
    local setup_script="${action_path}setup.sh"
    
    if [[ ! -f "$setup_script" ]]; then
        error "Setup script not found: $setup_script"
        return 1
    fi
    
    # Source the setup script
    info "Loading $action_name action..."
    # shellcheck disable=SC1090
    if ! source "$setup_script"; then
        error "Failed to source setup script: $setup_script"
        return 1
    fi
    
    # Call action_config to setup fields and defaults
    if declare -f action_config &>/dev/null; then
        info "Configuring $action_name..."
        action_config
    else
        error "action_config() not found in $setup_script"
        return 1
    fi
    
    # Execute the setup function
    info "Executing $action_name..."
    section_title "Action: $action_name"
    if ! action_setup; then
        error "Action setup failed for: $action_name"
        return 1
    fi
    
    success "Action completed: $action_name"
    return 0
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================
# Interrupt handler
trap 'newline; exit 130' SIGINT

# Setup cleanup trap
trap _main_stopHandler EXIT

# Setup runtime directory
declare -g RUNTIME_DIR
if ! setupRuntimeDir; then
    error "Failed to setup runtime directory"
    exit 1
else
    info "Runtime directory: $RUNTIME_DIR"
fi

# Discover available actions
readonly ACTIONS_DIR="${SCRIPT_DIR}/../actions"
declare -a ACTION_NAMES=()
declare -gA ACTION_DATA=()

if ! _nds_discover_actions; then
    error "Failed to discover actions"
    exit 1
fi

# Select action
selected_action=$(_nds_select_action)

# Init configuration system
if declare -f nds_config_init_system &>/dev/null; then
    info "Initializing configuration system..."
    nds_config_init_system || {
        error "Failed to initialize configuration system"
        exit 1
    }
else
    crash "Configuration system not available (nds_config_init_system not found)"
fi

# Execute selected action
_nds_execute_action "$selected_action" || exit 1

# =============================================================================
# END
# =============================================================================
exit 0
