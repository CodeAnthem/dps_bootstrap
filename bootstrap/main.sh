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

        # Collect NDS_* environment variables to preserve
        nds_vars=()
        while IFS='=' read -r name value; do
            if [[ $name == NDS_* ]]; then
                nds_vars+=("$name=$value")
            fi
        done < <(env)

        # Restart script with sudo, preserving only NDS_* variables
        if [[ ${#nds_vars[@]} -gt 0 ]]; then
            exec sudo "${nds_vars[@]}" bash "${BASH_SOURCE[0]}" "$@"
        else
            exec sudo bash "${BASH_SOURCE[0]}" "$@"
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

if ! _nds_discover_actions; then crash "Failed to discover actions"; fi

# Initialize configurator feature
if declare -f nds_cfg_init &>/dev/null; then
    nds_cfg_init || crash "Failed to initialize configurator"
else
    crash "Configurator not available (nds_cfg_init not found)"
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
