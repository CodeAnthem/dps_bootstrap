#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-16
# Description:   Entry point selector for DPS Bootstrap - routes to Deploy VM or Managed Node setup
# Feature:       Mode selection, library management, root validation, cleanup handling
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
# MODE SELECTION FUNCTIONS
# =============================================================================
# Select deployment mode
console "Choose deployment mode:"
console "  1) Deploy VM    - Management and deployment hub"
console "  2) Managed Node - Infrastructure node (server, workstation, etc.)"
console

# Read from terminal directly to avoid stdin pollution from piped script
if [[ -t 0 ]]; then
    # We have a real terminal
    read -p "Select mode [1-2, default=1]: " choice
else
    # No terminal (piped script), try to read from /dev/tty
    if [[ -c /dev/tty ]]; then
        console "Select mode [1-2, default=1]: "
        read choice < /dev/tty || {
            console "No input received, defaulting to Deploy VM"
            choice="1"
        }
    else
        # No TTY available, default to Deploy VM
        console "No interactive terminal available, defaulting to Deploy VM"
        choice="1"
    fi
fi

# Handle empty input
if [[ -z "$choice" ]]; then
    choice="1"
fi

case "$choice" in
    1|"")
        log "Selected mode: Deploy VM"
        # source "${SCRIPT_DIR}/setup_deploy_vm.sh"
        # deploy_vm_workflow
        ;;
    2)
        log "Selected mode: Managed Node"
        # source "${SCRIPT_DIR}/setup_managed_node.sh"
        # managed_node_workflow
        ;;
    *)
        console "Invalid selection '$choice', abort!"
        exit 1
        ;;
esac

# =============================================================================
# END
# =============================================================================
echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
exit 0
