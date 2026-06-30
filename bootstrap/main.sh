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
readonly SCRIPT_NAME="Nix Deploy System (a NixOS Bootstrapper)"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
readonly SCRIPT_DIR="${currentPath}"
readonly LIB_DIR="${currentPath}/lib"

# Declare global associative array for hook function names
declare -gA NDS_HOOK_FUNCTIONS=(
    ["exit_msg"]="hook_exit_msg" # Message to display on exit
    ["exit_cleanup"]="hook_exit_cleanup" # Cleanup to perform on exit
)

# =============================================================================
# IMPORT LIBRARIES
# =============================================================================
# shellcheck disable=SC1091
source "${LIB_DIR}/core/import.sh"


# =============================================================================
# HOOK FUNCTIONS
# =============================================================================
# shellcheck disable=SC2329 # Hook is called dynamically
_nds_callHook() {
    local hookName="$1"
    shift
    local hookFunction="${NDS_HOOK_FUNCTIONS[$hookName]}"
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
        section_header "Administrator privileges required"
        warn "NDS must run as root to partition disks and install."
        info "On the live ISO, log in as nixos and run with sudo — restarting now..."

        # Preserve NDS_* environment variables through sudo
        nds_vars=()
        while IFS='=' read -r name value; do
            if [[ "$name" =~ ^NDS_ ]]; then
                nds_vars+=("$name=$value")
            fi
        done < <(env)

        # Restart with sudo, preserving NDS_* and DEBUG variables
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
# Setup runtime directory - uses nds_runtime_init from core/runtime.sh when loaded.
setupRuntimeDir() {
    nds_runtime_init
}

# shellcheck disable=SC2329
purgeRuntimeDir() {
    nds_runtime_purge
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

    if [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]]; then
        return 0
    fi

    if [[ -n "$exit_msg" ]]; then
        console "$exit_msg"
    else
        case "${exit_code}" in
            0)
                success "Script completed successfully"
            ;;
            10)
                # NDS_ACTION_BACK — handled above; suppress duplicate messaging
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

    if [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]]; then
        return 0
    fi

    if [[ "$exit_code" -ne 0 ]]; then
        if [[ -d "${RUNTIME_DIR:-}" ]]; then
            warn "Install failed — runtime preserved at: ${RUNTIME_DIR}"
            [[ -d "${RUNTIME_DIR}/secrets" ]] && warn "Secrets in: ${RUNTIME_DIR}/secrets/"
        fi
        if [[ -n "${NDS_SECRETS_BUNDLE:-}" && -f "$NDS_SECRETS_BUNDLE" ]]; then
            warn "Secrets bundle preserved at: ${NDS_SECRETS_BUNDLE}"
        fi
        warn "Install log: ${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
        return 0
    fi

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

    if ! grep -q "^action_preview()" "$setup_script"; then
        debug "Action '$action_name': Missing action_preview() function"
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
    section_header "Choose an action"

    nds_ui_b ""
    nds_ui_choice_row "0" "Abort" "Exit the script"
    nds_ui_b ""

    local i=1
    for action_name in "${ACTION_NAMES[@]}"; do
        local description="${ACTION_DATA[${action_name}_description]}"
        nds_ui_choice_row "$i" "$action_name" "$description"
        ((i++))
    done

    nds_ui_b ""

    local choice max_choice
    max_choice="${#ACTION_NAMES[@]}"

    while true; do
        read -rsn1 -p "${NDS_UI_INDENT_B}Select action to preview [0-$max_choice]: " choice < /dev/tty
        echo >&2

        if [[ "$choice" == "0" ]]; then
            nds_ui_b "Operation aborted"
            exit 130
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_choice" ]]; then
            local selected_action="${ACTION_NAMES[$((choice-1))]}"
            current_action="$selected_action"
            return 0
        fi

        nds_ui_b "Invalid selection. Choose 0-$max_choice"
    done
}

_nds_run_action_preview() {
    local action_name="$1"

    if ! declare -f action_preview &>/dev/null; then
        error "action_preview() not found"
        return 1
    fi

    new_section
    section_header "Install preview"
    action_preview
    nds_ui_b "Press Y to continue, B to go back to the action menu."
    nds_ui_b ""
    nds_askUserContinue "Proceed with this action?"
    local prc=$?
    case "$prc" in
        0) return 0 ;;
        2) return "$NDS_ACTION_BACK" ;;
        *) return 130 ;;
    esac
}

_nds_execute_action() {
    local action_name="$1"
    local action_path="${ACTION_DATA[${action_name}_path]}"
    local setup_script="${action_path}setup.sh"
    local rc=0

    export NDS_CURRENT_ACTION="$action_name"

    if [[ ! -f "$setup_script" ]]; then
        error "Setup script not found: $setup_script"
        return 1
    fi

    info "Loading $action_name action..."
    if ! nds_import_file "$setup_script"; then
        error "Failed to import action setup script"
        return 1
    fi

    if declare -f action_config &>/dev/null; then
        info "Configuring $action_name..."
        nds_configurator_reset_for_action "$SCRIPT_DIR" || return 1
        action_config
    else
        error "action_config() not found in $setup_script"
        return 1
    fi

    rc=0
    _nds_run_action_preview "$action_name" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        return "$rc"
    fi

    info "Executing $action_name..."
    rc=0
    action_setup || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        if [[ "$rc" -eq "$NDS_ACTION_BACK" ]]; then
            return "$NDS_ACTION_BACK"
        fi
        error "Action setup failed for: $action_name"
        return "$rc"
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
nds_import_file "${LIB_DIR}/core/import.sh" || exit 1
nds_bootstrap_load_libs "$SCRIPT_DIR" || exit 1

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
declare -g RUNTIME_DIR
if ! setupRuntimeDir; then crash "Failed to setup runtime directory"; fi
info "Runtime directory: $RUNTIME_DIR"
nds_install_log "NDS session started (v$SCRIPT_VERSION)"

# Discover available actions
readonly ACTIONS_DIR="${SCRIPT_DIR}/../actions"
declare -a ACTION_NAMES=()
declare -gA ACTION_DATA=()
if ! _nds_discover_actions; then crash "Failed to discover actions"; fi

# Initialize configurator and installation (loaded by nds_bootstrap_load_libs)
success "Bootstrapper 'NDS' libraries loaded"

# Select action
declare -g current_action

nds_main() {
    local rc=0
    while true; do
        _nds_select_action
        rc=0
        _nds_execute_action "$current_action" || rc=$?
        if [[ "$rc" -eq "$NDS_ACTION_BACK" ]]; then
            NDS_CURRENT_ACTION=""
            continue
        fi
        if [[ "$rc" -ne 0 ]]; then
            crash "Failed to execute action"
        fi
        break
    done
}

nds_main

# =============================================================================
# END
# =============================================================================
exit 0
