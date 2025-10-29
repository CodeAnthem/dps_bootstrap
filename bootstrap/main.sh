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
readonly SCRIPT_VERSION="3.0.8"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper)"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"

# Declare global associative array for hook function names
declare -gA DPS_HOOK_FUCNTIONS=(
    ["exit_msg"]="phase_exit_msg" # Message to display on exit
    ["exit_cleanup"]="phase_exit_cleanup" # Cleanup to perform on exit
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
    info "This script requires root privileges."
    echo " -> Attempting to restart with sudo..."
    
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
discover_actions() {
    local action_count=0
    
    if [[ ! -d "$ACTIONS_DIR" ]]; then
        error "Actions directory not found: $ACTIONS_DIR"
    fi
    
    for action_dir in "$ACTIONS_DIR"/*/; do
        [[ -d "$action_dir" ]] || continue
        
        local action_name
        action_name=$(basename "$action_dir")
        local setup_script="${action_dir}setup.sh"
        
        # Skip test action unless DPS_TEST=true
        if [[ "$action_name" == "test" && "${DPS_TEST:-false}" != "true" ]]; then
            debug "Skipping test action (DPS_TEST not set to true)"
            continue
        fi
        
        if [[ -f "$setup_script" ]]; then
            # Parse description from header (first 10 lines only, no sourcing)
            local description
            description=$(head -n 10 "$setup_script" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null || echo "No description available")
            
            ((++action_count))
            ACTIONS[$action_count]="$action_name"
            ACTION_DESCRIPTIONS[$action_count]="$description"
            
            debug "Discovered action: $action_name - $description"
        else
            debug "Skipping $action_name: no setup.sh found"
        fi
    done
    
    if [[ $action_count -eq 0 ]]; then
        error "No valid actions found in $ACTIONS_DIR"
    fi
    
    info "Discovered $action_count available actions"
}

# =============================================================================
# ACTION SELECTION
# =============================================================================
select_action() {
    new_section
    section_header "Choose bootstrap action"
    
    # Display available actions in correct order (sorted by key)
    local sorted_keys
    mapfile -t sorted_keys < <(printf '%s\n' "${!ACTIONS[@]}" | sort -n)
    
    console "  0) Abort - Exit the script"
    for i in "${sorted_keys[@]}"; do
        console "  $i) ${ACTIONS[$i]} - ${ACTION_DESCRIPTIONS[$i]}"
    done
    
    local choice validOptions max_choice
    max_choice="${#ACTIONS[@]}"
    validOptions="0 $(seq -s ' ' 1 "$max_choice")"
    
    # Loop until valid choice is made
    while true; do
        # printf "Select action [0-$max_choice]: "
        read -rsn1 -p "     -> Select action: " choice < /dev/tty
        
        # Handle empty input (Enter key)
        if [[ -z "$choice" ]]; then
            console "Please select a valid option ($validOptions)"
            continue
        fi
        
        # Check for abort option
        if [[ "$choice" == "0" ]]; then
            console "Operation aborted"
            break
        fi
                
        # Validate choice exists
        if [[ "${ACTIONS[$choice]:-}" ]]; then
            console "${ACTIONS[$choice]}"
            break
        fi

        # Invalid selection
        console "Invalid selection '$choice' - Valid options: ($validOptions)"
        continue
    done

    # Handle valid selection
    if ((choice == 0)); then exit 1; fi # Abort
    echo "$choice"
}

# =============================================================================
# ACTION EXECUTION
# =============================================================================
execute_action() {
    local action_number="$1"
    local action_name="${ACTIONS[$action_number]}"
    local setup_script="${ACTIONS_DIR}/${action_name}/setup.sh"
        
    # Source the setup script
    if [[ -f "$setup_script" ]]; then
        # shellcheck disable=SC1090
        if ! source "$setup_script"; then
            error "Failed to source setup script: $setup_script"
            exit 2
        fi
        success "Setup script sourced successfully"
    else
        error "Setup script not found: $setup_script"
    fi
    
    # Check if setup function exists
    if ! declare -f setup >/dev/null; then
        error "Setup function not found in $setup_script"
    fi
    
    # Execute the setup function
    info "Executing $action_name setup..."
    section_title "Action: $action_name"
    if ! setup; then
        error "Action setup failed for: $action_name"
    fi
    success "Action completed successfully: $action_name"
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================
# Interrupt handler
trap 'newline; exit 130' SIGINT

# Setup cleanup trap
trap _main_stopHandler EXIT

# Display script header
section_title "$SCRIPT_NAME v$SCRIPT_VERSION"

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
declare -A ACTIONS
declare -A ACTION_DESCRIPTIONS
discover_actions

# Select action
selected_action=$(select_action)

# Init configuration modules
_nds_config_init_modules

# Execute selected action
execute_action "$selected_action"

# =============================================================================
# END
# =============================================================================
exit 0
