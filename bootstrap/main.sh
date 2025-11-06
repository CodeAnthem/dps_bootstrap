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

# ----------------------------------------------------------------------------------
# SCRIPT VARIABLES
# ----------------------------------------------------------------------------------
# Meta Data
readonly SCRIPT_VERSION="4.0.1"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper) *dev*"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"
readonly LIB_DIR="${currentPath}/lib"


# ----------------------------------------------------------------------------------
# IMPORT LIBRARIES
# ----------------------------------------------------------------------------------
# shellcheck disable=SC1091
source "${LIB_DIR}/libImporter.sh" || { echo "Failed to import libraries" >&2; exit 1; }
nds_import_dir "${LIB_DIR}/output"
nds_import_dir "${LIB_DIR}/essentials"
nds_import_dir "${LIB_DIR}/mainCore"













# ----------------------------------------------------------------------------------
# HANDLING EXIT AND CLEANUP
# ----------------------------------------------------------------------------------
nds_trap_init
# Register exit hooks
nds_hook_register "exit_msg" "hook_exit_msg"
nds_hook_register "exit_cleanup" "hook_exit_cleanup"

# shellcheck disable=SC2329
_main_onExit() {
    local exit_code=$?
    local exit_msg=""
    exit_msg=$(nds_hook_call "exit_msg" "$exit_code" || true)

    if [[ -n "$exit_msg" ]]; then
        console "$exit_msg"
    else
        case "${exit_code}" in
            2) success "Placeholder" ;;
        esac
    fi
}; nds_trap_registerExit _main_onExit

# shellcheck disable=SC2329
_main_onCleanup() {
    info "Cleaning up session"
    purgeRuntimeDir
    nds_hook_call "exit_cleanup" "$exit_code" || true # Call cleanup hook
}; nds_trap_registerCleanup _main_onCleanup

# ----------------------------------------------------------------------------------
# START UP & ARGUMENTS
# ----------------------------------------------------------------------------------
nds_runWithRoot NDS_

if nds_arg_has "--auto-confirm"; then
    export NDS_AUTO_CONFIRM=true
fi
if nds_arg_has "--help"; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto-confirm    Skip all user confirmation prompts"
    echo "  --help, -h        Show this help message"
    echo "value is: $(nds_arg_value "--auto-confirm")"
    exit 0
fi


# ----------------------------------------------------------------------------------
# MAIN WORKFLOW
# ----------------------------------------------------------------------------------
# Display script header
section_title "$SCRIPT_NAME v$SCRIPT_VERSION"

echo exit
exit 0
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

# ----------------------------------------------------------------------------------
# END
# ----------------------------------------------------------------------------------
exit 0
