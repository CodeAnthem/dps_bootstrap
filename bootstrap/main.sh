#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-16
# Description:   Entry point selector for DPS Bootstrap - dynamically discovers and executes actions
# Feature:       Action discovery, library management, root validation, cleanup handling
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

# =============================================================================
# SCRIPT VARIABLES
# =============================================================================
# Meta Data
readonly SCRIPT_VERSION="3.0.6"
readonly SCRIPT_NAME="NixOS Bootstrapper | DPS Project"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="${currentPath}"

# =============================================================================
# IMPORT LIBRARIES
# =============================================================================
readonly LIB_DIR="${SCRIPT_DIR}/lib"
# Load all .sh files from $LIB_DIR
for file in "$LIB_DIR"/*.sh; do
    # Skip if no matches
    [[ -e "$file" ]] || continue

    # Try to source, catch errors
    # shellcheck disable=SC1090
    if ! source "$file"; then echo >&2 " [Error] Failed to source: $file"; fi
done


# =============================================================================
# ROOT CHECK
# =============================================================================
# Root privilege check with sudo fallback
if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges."
    echo "Attempting to restart with sudo..."
    exec sudo "$0" "$@"
fi


# =============================================================================
# SETUP RUNTIME DIRECTORY
# =============================================================================
# Setup runtime directory - declare and assign separately
timestamp=""
printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
readonly RUNTIME_DIR="/tmp/dps_${timestamp}_$$"

# Create runtime directory
mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

log "Runtime directory: $RUNTIME_DIR"


# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================
# Enhanced cleanup function with exit code detection
# shellcheck disable=SC2329
cleanup() {
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log "Script completed successfully"
    else
        log "Script aborted with exit code: $exit_code"
    fi

    if [[ -d "${RUNTIME_DIR:-}" ]]; then
        log "Cleaning up runtime directory: $RUNTIME_DIR"
        rm -rf "$RUNTIME_DIR"
    fi

    exit "$exit_code"
}

# Setup cleanup trap
trap cleanup EXIT


# =============================================================================
# WELCOME
# =============================================================================
echo
echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="


# =============================================================================
# ACTION DISCOVERY
# =============================================================================
# Discover available actions from actions/ folder
readonly ACTIONS_DIR="${SCRIPT_DIR}/../actions"
declare -A ACTIONS
declare -A ACTION_DESCRIPTIONS

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
        
        if [[ -f "$setup_script" ]]; then
            # Parse description from header (first 10 lines only, no sourcing)
            local description
            description=$(head -n 10 "$setup_script" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null || echo "No description available")
            
            ((action_count++))
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
    
    log "Discovered $action_count available actions"
}

# =============================================================================
# ACTION SELECTION
# =============================================================================
select_action() {
    console "Choose bootstrap action:"
    
    # Display available actions
    for i in "${!ACTIONS[@]}"; do
        console "  $i) ${ACTIONS[$i]} - ${ACTION_DESCRIPTIONS[$i]}"
    done
    console
    
    local choice
    local default_choice="1"
    
    # Read from terminal directly to avoid stdin pollution from piped script
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -p "Select action [1-${#ACTIONS[@]}, default=$default_choice]: " choice
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            console "Select action [1-${#ACTIONS[@]}, default=$default_choice]: "
            read choice < /dev/tty || {
                console "No input received, defaulting to action $default_choice"
                choice="$default_choice"
            }
        else
            # No TTY available, default to first action
            console "No interactive terminal available, defaulting to action $default_choice"
            choice="$default_choice"
        fi
    fi
    
    # Handle empty input
    if [[ -z "$choice" ]]; then
        choice="$default_choice"
    fi
    
    # Validate choice
    if [[ ! "${ACTIONS[$choice]:-}" ]]; then
        error "Invalid selection '$choice'. Please choose 1-${#ACTIONS[@]}"
    fi
    
    echo "$choice"
}

# =============================================================================
# ACTION EXECUTION
# =============================================================================
execute_action() {
    local action_number="$1"
    local action_name="${ACTIONS[$action_number]}"
    local setup_script="${ACTIONS_DIR}/${action_name}/setup.sh"
    
    log "Selected action: $action_name"
    
    # Source the setup script
    if [[ -f "$setup_script" ]]; then
        # shellcheck disable=SC1090
        if ! source "$setup_script"; then
            error "Failed to source setup script: $setup_script"
        fi
    else
        error "Setup script not found: $setup_script"
    fi
    
    # Check if setup function exists
    if ! declare -f setup >/dev/null; then
        error "Setup function not found in $setup_script"
    fi
    
    # Execute the setup function
    log "Executing $action_name setup..."
    if ! setup; then
        error "Action setup failed for: $action_name"
    fi
    
    success "Action completed successfully: $action_name"
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================
# Discover available actions
discover_actions

# Select action
selected_action=$(select_action)

# Execute selected action
execute_action "$selected_action"

# =============================================================================
# END
# =============================================================================
echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
exit 0
