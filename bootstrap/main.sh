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
readonly SCRIPT_VERSION="4.0.1"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper) *dev*"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"
readonly LIB_DIR="${currentPath}/lib"

# Declare global associative array for hook function names
declare -gA NDS_HOOK_FUCNTIONS=(
    ["exit_msg"]="hook_exit_msg" # Message to display on exit
    ["exit_cleanup"]="hook_exit_cleanup" # Cleanup to perform on exit
)

# =============================================================================
# IMPORT LIBRARIES
# =============================================================================

# Global variable to store import errors
declare -g NDS_IMPORT_ERRORS=""

# Internal function: Validate and import a single file
# Usage: _nds_import_and_validate_file <filepath>
# Returns: 0 on success, 1 on failure (errors stored in NDS_IMPORT_ERRORS)
_nds_import_and_validate_file() {
    local filepath="$1"
    local err_output

    # Validate by running in a strict subshell and capture stderr output
    if ! err_output=$(bash -euo pipefail "$filepath" 2>&1); then
        # Clean the path prefix "$filepath: " from each line
        local cleaned=""
        local line
        while IFS= read -r line; do
            if [[ "$line" == "$filepath:"* ]]; then
                line="${line#"$filepath: "}"
            fi
            cleaned+=$'\n'" -> $line"
        done <<< "$err_output"

        # Store error in global variable
        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to validate: $filepath${cleaned}"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to validate: $filepath${cleaned}"
        fi
        return 1
    fi

    # Source in current shell (affects parent environment)
    # shellcheck disable=SC1090
    if ! source "$filepath"; then
        # Store source error in global variable
        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to source: $filepath"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to source: $filepath"
        fi
        return 1
    fi

    return 0
}

# Display collected import errors and clear the error buffer
# Usage: _nds_import_showErrors
# Returns: 0 if no errors, 1 if errors were present
_nds_import_showErrors() {
    if [[ -n "$NDS_IMPORT_ERRORS" ]]; then
        echo "$NDS_IMPORT_ERRORS" >&2
        NDS_IMPORT_ERRORS=""  # Clear errors after showing
        return 1
    fi
    return 0
}

# Import a single file with validation
# Usage: nds_import_file <filepath>
# Returns: 0 on success, 1 on failure (with errors displayed)
nds_import_file() {
    local filepath="$1"
    
    [[ -f "$filepath" ]] || {
        echo "Error: File not found: $filepath" >&2
        return 1
    }
    
    NDS_IMPORT_ERRORS=""  # Clear previous errors
    _nds_import_and_validate_file "$filepath"
    _nds_import_showErrors
}

# Import all .sh files from a directory
# Usage: nds_import_dir <directory> [recursive]
# If recursive is "true" will descend into subdirectories (skipping names beginning with "_").
# Returns: 0 on success, 1 if any file failed
nds_import_dir() {
    local directory recursive item basename
    local had_error=false

    directory="${1:-}"
    [[ -d "$directory" ]] || {
        echo "Error: Directory not found: $directory" >&2
        return 1
    }

    recursive="${2:-false}"
    [[ "$recursive" == "true" || "$recursive" == "false" ]] || {
        echo "Error: Invalid recursive parameter: $recursive" >&2
        return 1
    }

    NDS_IMPORT_ERRORS=""  # Clear previous errors
    local had_error=false

    for item in "$directory"/*; do
        [[ -e "$item" ]] || continue   # Skip when glob doesn't match (empty dir)

        basename="$(basename "$item")"

        # Skip files/folders starting with underscore
        [[ "${basename:0:1}" == "_" ]] && continue

        # If directory, maybe recurse
        if [[ -d "$item" ]]; then
            if [[ "$recursive" == "true" ]]; then
                nds_import_dir "$item" "$recursive" || return 1
            fi
            continue
        fi

        # Only consider .sh files
        if [[ "${basename: -3}" == ".sh" ]]; then
            if ! _nds_import_and_validate_file "$item"; then
                had_error=true
            fi
        fi
    done

    # Show collected errors and return status
    if [[ "$had_error" == "true" ]]; then
        _nds_import_showErrors
        return 1
    fi

    return 0
}


# =============================================================================
# HOOK FUNCTIONS
# =============================================================================
# shellcheck disable=SC2329 # Hook is called dynamically
_nds_callHook() {
    local hookName="$1"
    shift
    local hookFunction="${NDS_HOOK_FUCNTIONS[$hookName]}"
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
runWithRoot() {
    if [[ $EUID -ne 0 ]]; then
        new_section
        section_header "Root Privilege Required"
        warn "This script requires root privileges."
        info "Attempting to restart with sudo..."

        # Preserve NDS_* and NDS_* environment variables through sudo
        nds_vars=()
        while IFS='=' read -r name value; do
            if [[ "$name" =~ ^(NDS_|NDS_) ]]; then
                nds_vars+=("$name=$value")
            fi
        done < <(env)

        # Restart with sudo, preserving NDS_*, NDS_*, and DEBUG variables
        if [[ ${#nds_vars[@]} -gt 0 ]]; then
            exec sudo "${nds_vars[@]}" DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "$@"
        else
            exec sudo DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "$@"
        fi
    else
        success "Root privileges confirmed"
    fi
}


# =============================================================================
# RUNTIME DIRECTORY
# =============================================================================
# Setup runtime directory - declare and assign separately
setupRuntimeDir() {
    local timestamp=""
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    [[ -z "$timestamp" ]] && return 1
    NDS_RUNTIME_DIR="/tmp/nds_runtime_${timestamp}_$$"

    # Create runtime directory
    mkdir -p "$NDS_RUNTIME_DIR" || return 1
    chmod 700 "$NDS_RUNTIME_DIR" || return 1
    return 0
}

# shellcheck disable=SC2329
purgeRuntimeDir() {
    if [[ -d "${NDS_RUNTIME_DIR:-}" ]]; then
        if rm -rf "$NDS_RUNTIME_DIR"; then
            success " > Removed runtime directory: $NDS_RUNTIME_DIR"
        else
            error " > Failed to remove runtime directory: $NDS_RUNTIME_DIR"
        fi
    fi

    # shellcheck disable=SC2010
    ls -l /tmp/ | grep -i "dps" # TODO: Remove after debugging
}


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================
declare -g fatal_message=""
crash() {
    fatal_message="$1"
    exit 200
}

# shellcheck disable=SC2329
_main_stopHandler() {
    local exit_code=$?
    # Get custom exit message if exists
    local exit_msg=""
    exit_msg=$(_nds_callHook "exit_msg" "$exit_code" || true)

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
                fatal "Internal error! - ${fatal_message:-}"
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
    _nds_callHook "exit_cleanup" "$exit_code" || true
}


# =============================================================================
# ACTION DISCOVERY & SELECTION & EXECUTION
# =============================================================================
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

        # Skip test action unless NDS_TEST=true
        if [[ "$action_name" == "test" && "${NDS_TEST:-false}" != "true" ]]; then
            debug "Skipping test action (NDS_TEST not set)"
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

        # Handle abort
        if [[ "$choice" == "0" ]]; then
            console "Operation aborted"
            exit 130
        fi

        # Validate choice is a number and in range
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_choice" ]]; then
            local selected_action="${ACTION_NAMES[$((choice-1))]}"
            console "$selected_action"
            action_name="$selected_action" # return value
            action_description="${ACTION_DATA[${action_name}_description]}"
            action_path="${ACTION_DATA[${action_name}_path]}"
            return 0
        fi

        # Invalid selection
        console "Invalid selection. Choose 0-$max_choice"
    done
}

_nds_execute_action() {
    local setup_script="${action_path}/setup.sh"

    if [[ ! -f "$setup_script" ]]; then
        error "Setup script not found: $setup_script"
        return 1
    fi

    # Import the setup script with validation
    info "Loading $action_name action..."
    if ! nds_import_file "$setup_script"; then
        error "Failed to import action setup script"
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
# COMMAND-LINE ARGUMENTS
# =============================================================================
# Save original arguments for sudo restart
declare -a ORIGINAL_ARGS=("$@")

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-confirm)
            export NDS_AUTO_CONFIRM=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto-confirm    Skip all user confirmation prompts"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# =============================================================================
# MAIN WORKFLOW
# =============================================================================
# Load libraries
nds_import_dir "${LIB_DIR}" false || exit 1

# Run with root (pass original args for sudo restart)
if [[ ${#ORIGINAL_ARGS[@]} -gt 0 ]]; then
    runWithRoot "${ORIGINAL_ARGS[@]}"
else
    runWithRoot
fi

# Display script header
section_title "$SCRIPT_NAME v$SCRIPT_VERSION"

# Signal handlers
trap 'newline; exit 130' SIGINT # Interrupt handler
trap _main_stopHandler EXIT # Setup cleanup trap
success "Signal handlers initialized"

# Setup runtime directory
declare -g NDS_RUNTIME_DIR
if ! setupRuntimeDir; then crash "Failed to setup runtime directory"; fi
info "Runtime directory: $NDS_RUNTIME_DIR"

# Discover available actions
readonly ACTIONS_DIR="${SCRIPT_DIR}/../actions"
declare -a ACTION_NAMES=()
declare -gA ACTION_DATA=()
if ! _nds_discover_actions; then crash "Failed to discover actions"; fi

# Initialize configurator feature
if declare -f nds_configurator_init &>/dev/null; then
    nds_configurator_init || crash "Failed to initialize configurator"
else
    crash "Configurator not available (nds_configurator_init not found)"
fi

# Initialize partition feature
if declare -f nds_partition_init &>/dev/null; then
    nds_partition_init || crash "Failed to initialize partition feature"
else
    crash "Partition feature not available (nds_partition_init not found)"
fi

success "Bootstrapper 'NDS' libraries loaded"

# Select action
declare -g action_name
declare -g action_description
declare -g action_path
_nds_select_action
# shellcheck disable=SC2034
action_description="${ACTION_DATA[${action_name}_description]}"
action_path="${ACTION_DATA[${action_name}_path]}"


# Execute selected action
_nds_execute_action || crash "Failed to execute action"

# =============================================================================
# END
# =============================================================================
exit 0
