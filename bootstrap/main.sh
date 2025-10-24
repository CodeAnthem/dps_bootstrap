#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-24
# Description:   Entry point selector for DPS Bootstrap - dynamically discovers and executes actions
# Feature:       Action discovery, library management, root validation, cleanup handling
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

# =============================================================================
# SCRIPT VARIABLES
# =============================================================================
# Meta Data
readonly SCRIPT_VERSION="3.0.7"
readonly SCRIPT_NAME="NixOS Bootstrapper | DPS Project"

# Script Path - declare and assign separately to avoid masking return values
currentPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="${currentPath}"

# =============================================================================
# IMPORT LIBRARIES
# =============================================================================
readonly LIB_DIR="${SCRIPT_DIR}/lib"

# Recursively source all .sh files in lib folder
# Ignores files and folders starting with underscore (_)
source_lib_recursive() {
    local dir="$1"
    
    # Process .sh files in current directory
    for file in "$dir"/*.sh; do
        [[ -e "$file" ]] || continue
        
        # Skip files starting with underscore
        local basename
        basename=$(basename "$file")
        [[ "$basename" =~ ^_ ]] && continue
        
        # Source the file
        # shellcheck disable=SC1090
        if ! source "$file"; then 
            error "Failed to source: $file"
        fi
    done
    
    # Recursively process subdirectories
    for subdir in "$dir"/*/; do
        [[ -d "$subdir" ]] || continue
        
        # Skip directories starting with underscore
        local dirname
        dirname=$(basename "$subdir")
        [[ "$dirname" =~ ^_ ]] && continue
        
        # Recurse into subdirectory
        source_lib_recursive "$subdir"
    done
}

# Load all libraries recursively
source_lib_recursive "$LIB_DIR"


# =============================================================================
# START MESSAGE
# =============================================================================
section_title "$SCRIPT_NAME v$SCRIPT_VERSION"


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
# SETUP RUNTIME DIRECTORY
# =============================================================================
# Setup runtime directory - declare and assign separately
setupRuntimeDir() {
    timestamp=""
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    readonly RUNTIME_DIR="/tmp/dps_${timestamp}_$$"

    # Create runtime directory
    mkdir -p "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"
    info "Runtime directory: $RUNTIME_DIR"
}
setupRuntimeDir

# shellcheck disable=SC2329
purgeRuntimeDir() {
    if [[ -d "${RUNTIME_DIR:-}" ]]; then
        if rm -rf "$RUNTIME_DIR"; then
            success "Runtime directory cleaned up: $RUNTIME_DIR"
        else
            error "Failed to clean up runtime directory: $RUNTIME_DIR"
        fi
    fi
}


# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================
# Enhanced cleanup function with exit code detection
# shellcheck disable=SC2329
cleanup() {
    local exit_code=$?
    
    # Always add newline to clear prompt line
    # This handles CTRL+C in prompts and abort scenarios cleanly
    newline
    
    info "Stopping DPS Bootstrap"

    # Print error messages only for actual failures
    if [[ $exit_code -eq 1 ]]; then
        error "Script aborted"
    elif [[ $exit_code -eq 130 ]]; then
        # SIGINT (CTRL+C) - silent exit
        :
    elif (( exit_code > 1 )); then
        error "Script failed with exit code: $exit_code"
    fi

    # Cleanup
    info "Cleaning up session"
    purgeRuntimeDir
}

# Setup cleanup trap
trap cleanup EXIT


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

# Discover available actions
discover_actions

# Select action
selected_action=$(select_action)

# Execute selected action
execute_action "$selected_action"

# =============================================================================
# END
# =============================================================================
exit 0
