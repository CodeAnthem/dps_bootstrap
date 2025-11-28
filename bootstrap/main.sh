#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-29
# Description:   Entry point selector for DPS Bootstrap - dynamically discovers and executes actions
# Feature:       Action discovery, library management, root validation, cleanup handling
# ==================================================================================================
# shellcheck disable=SC2162
# set -uo pipefail

# ----------------------------------------------------------------------------------
# SCRIPT VARIABLES
# ----------------------------------------------------------------------------------
# Meta Data
readonly SCRIPT_VERSION="4.0.2"
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper) *dev*"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"

# Library Path
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly DEV_ACTIONS=("test")


# ----------------------------------------------------------------------------------
# IMPORT LIBRARIES
# ----------------------------------------------------------------------------------
# IMPORT XBS LIBRARIES
readonly XBASHLIB_LIB_DIR="${SCRIPT_DIR}/xBashLib" # Directory for standalone libraries
# shellcheck disable=SC1091
source "${XBASHLIB_LIB_DIR}/libImporter/libImporter.sh" || { echo "Failed to import libraries" >&2; exit 1; }
import_named "${XBASHLIB_LIB_DIR}/trapMultiplexer" # Signal handler
import_named "${XBASHLIB_LIB_DIR}/streams" # Output feature
trap_named "streamsCleanup" 'stream_cleanup' EXIT # Cleanup FDs on exit
info "Stuff loaded"
exit

# Debug ENV control
if [[ "${NDS_DEBUG:-}" == "true" ]]; then stream_function debug --enable; fi
if [[ "${NDS_DEBUG:-}" == "false" ]]; then stream_function debug --disable; fi

# IMPORT NDS LIBRARIES
import_dir "${LIB_DIR}/output"
import_dir "${LIB_DIR}/genericHelpers"
import_dir "${LIB_DIR}/actionHandlers"


# ----------------------------------------------------------------------------------
# HANDLING EXIT AND CLEANUP
# ----------------------------------------------------------------------------------
# Register exit hooks
nds_hook_register "exit_msg" "hook_exit_msg"
nds_hook_register "exit_cleanup" "hook_exit_cleanup"

# shellcheck disable=SC2329
_main_onExit() {
    local exitCode=$?
    echo "is this ever executed: _main_onExit()"
    local exitMsg=""
    reset
    exitMsg=$(nds_hook_call "exit_msg" "$exitCode" || true)

    if [[ -n "$exitMsg" ]]; then
        console "$exitMsg"
    else
        case "${exitCode}" in
            2) success "Placeholder" ;;
        esac
    fi
}; 
trap_named "cleanup" '_main_onExit' EXIT # Cleanup FDs on exit
# nds_trap_registerExit _main_onExit

# shellcheck disable=SC2329
_main_onCleanup() {
    local exitCode="$1"
    echo "is this ever executed: _main_onCleanup()"
    info "Cleaning up session"
    nds_hook_call "exit_cleanup" "$exitCode" || true # Call cleanup hook
};
# nds_trap_registerCleanup _main_onCleanup


# ----------------------------------------------------------------------------------
# INITIALIZE
# ----------------------------------------------------------------------------------
nds_runAsSudo "$0" -p "NDS_" "$@"
nds_trap_init && success "Signal handlers initialized"
nds_arg_parse "$@" # Register arguments
nds_setupRuntimeDir "/tmp/nds_runtime" true || crash "Failed to setup runtime directory"
nds_trap_registerCleanup "tui::shutdown"
tui::init "$SCRIPT_NAME v$SCRIPT_VERSION" "Waiting for action"

# ----------------------------------------------------------------------------------
# ARGUMENTS
# ----------------------------------------------------------------------------------
if nds_arg_has "--auto"; then export NDS_AUTO_CONFIRM=true; fi
if nds_arg_has "--debug"; then debug_set "true"; fi
if nds_arg_has "--help"; then
    echo "Options:"
    echo "  --auto            Skip all user confirmation prompts"
    echo "  --debug           Enable debug mode"
    echo "  --action,         Select action to run"
    echo "  --help, -h        Show this help message"
    exit 0
fi


# ----------------------------------------------------------------------------------
# MAIN WORKFLOW
# ----------------------------------------------------------------------------------
# Discover available actions
nds_action_discover "${SCRIPT_DIR}/../actions" "${DEV_ACTIONS[@]}" "true" || crash "Failed to discover actions"
tui::body_append "$(date '+%Y-%m-%d %H:%M:%S') Discovered ${#ACTION_NAMES[@]} actions"
tui::draw_progress 1 5
# Display script header
# section_title "$SCRIPT_NAME v$SCRIPT_VERSION"


# Select action
# nds_action_autoSelectOrMenu "$(nds_arg_value "--action")"
tui::draw_progress 3 5
testfn() { sleep 3; }
tui::run_with_spinner "Testing function" testfn

# pid=$(tui::task_start "Installing packages" bash -c 'sleep 4; echo "apt install done"')

tui::draw_progress 5 5

echo exit
exit 0

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




# Execute selected action
_nds_execute_action || crash "Failed to execute action"

# ----------------------------------------------------------------------------------
# END
# ----------------------------------------------------------------------------------
exit 0
