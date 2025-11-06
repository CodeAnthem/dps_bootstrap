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
# Register exit hooks
nds_hook_register "exit_msg" "hook_exit_msg"
nds_hook_register "exit_cleanup" "hook_exit_cleanup"

# shellcheck disable=SC2329
_main_onExit() {
    local exitCode=$?
    local exitMsg=""
    exitMsg=$(nds_hook_call "exit_msg" "$exitCode" || true)

    if [[ -n "$exitMsg" ]]; then
        console "$exitMsg"
    else
        case "${exitCode}" in
            2) success "Placeholder" ;;
        esac
    fi
}; nds_trap_registerExit _main_onExit

# shellcheck disable=SC2329
_main_onCleanup() {
    local exitCode="$1"
    info "Cleaning up session"
    nds_hook_call "exit_cleanup" "$exitCode" || true # Call cleanup hook
}; nds_trap_registerCleanup _main_onCleanup


# ----------------------------------------------------------------------------------
# INITIALIZE
# ----------------------------------------------------------------------------------
nds_runAsSudo "$0" -p "NDS_" "$@"
nds_trap_init && success "Signal handlers initialized"
nds_arg_parse "$@" # Register arguments
nds_setupRuntimeDir "/tmp/nds_runtime" true || crash "Failed to setup runtime directory"


# ----------------------------------------------------------------------------------
# ARGUMENTS
# ----------------------------------------------------------------------------------
if nds_arg_has "--auto"; then export NDS_AUTO_CONFIRM=true; fi
if nds_arg_has "--help"; then
    echo "Options:"
    echo "  --auto            Skip all user confirmation prompts"
    echo "  --action,         Select action to run"
    echo "  --help, -h        Show this help message"
    exit 0
fi


# ----------------------------------------------------------------------------------
# MAIN WORKFLOW
# ----------------------------------------------------------------------------------
# Display script header
section_title "$SCRIPT_NAME v$SCRIPT_VERSION"

echo "exit - echo ${NDS_RUNTIME_DIR}"
exit



# Discover available actions
nds_action_discover "${SCRIPT_DIR}/../actions" "("test")" "true" || crash "Failed to discover actions"

# Select action
nds_action_autoSelectOrMenu "$(nds_arg_value "--action")"

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
