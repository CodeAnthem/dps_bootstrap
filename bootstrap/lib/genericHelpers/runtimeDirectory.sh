#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Runtime directory creation and cleanup utilities
# Feature:       Creates secure temporary runtime folder and purges it on exit
# ==================================================================================================

# Public: Create or reuse a secure runtime directory
# Usage: nds_setupRuntimeDir <baseFolder> [addTimestamp]
# Example: nds_setupRuntimeDir "/tmp/nds_runtime" true
# Notes:
#   - Declares NDS_RUNTIME_DIR globally.
#   - If NDS_RUNTIME_DIR already exists and is valid, it will be reused.
nds_setupRuntimeDir() {
    local baseFolder="$1"
    local addTimestamp="${2:-true}"
    local timestamp=""

    # Skip creation if already defined and exists
    if [[ -n "${NDS_RUNTIME_DIR:-}" ]]; then
        info "Using existing runtime directory: $NDS_RUNTIME_DIR"
        return 0
    fi

    declare -g NDS_RUNTIME_DIR=""

    # Generate unique timestamp if requested
    if [[ "$addTimestamp" == "true" ]]; then
        if ! printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1 2>/dev/null; then
            timestamp="$(date +%Y%m%d_%H%M%S)"
        fi
        NDS_RUNTIME_DIR="${baseFolder}_${timestamp}_$$"
    else
        NDS_RUNTIME_DIR="$baseFolder"
    fi

    # Create runtime directory
    mkdir -p "$NDS_RUNTIME_DIR" || {
        error "Failed to create runtime directory: $NDS_RUNTIME_DIR"
        return 1
    }

    chmod 700 "$NDS_RUNTIME_DIR" || {
        error "Failed to set permissions for: $NDS_RUNTIME_DIR"
        return 1
    }

    pass "Created runtime directory: $NDS_RUNTIME_DIR"
    nds_trap_registerCleanup "nds_purgeRuntimeDir"
    return 0
}

# Public: Remove runtime directory if present
# Usage: nds_purgeRuntimeDir
nds_purgeRuntimeDir() {
    if [[ -n "${NDS_RUNTIME_DIR:-}" && -d "$NDS_RUNTIME_DIR" ]]; then
        if rm -rf "$NDS_RUNTIME_DIR"; then
            pass "Removed runtime directory: $NDS_RUNTIME_DIR"
        else
            error "Failed to remove runtime directory: $NDS_RUNTIME_DIR"
        fi
    fi
}
