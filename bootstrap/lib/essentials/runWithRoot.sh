#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Re-exec script with sudo while preserving selected environment variables
# Feature:       Root privilege elevation with flexible variable prefix filtering
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Run a script as root, preserving specific environment variable prefixes.
# Usage:
#   nds_runAsSudo <targetScript> [options]
#
# Options:
#   -i | --ignore-case        Match prefixes case-insensitively (default: false)
#   -p | --prefix <prefix>    Add a variable prefix to preserve (can repeat)
#
# Example:
#   nds_runAsSudo "$0" -i -p "NDS_" -p "DPS_"
# --------------------------------------------------------------------------------------------------
nds_runAsSudo() {
    local targetScript=""
    local ignoreCase="false"
    local -a prefixes=()
    local -a preservedVars=()
    local prefix name value envLine

    # --- Argument Parsing -------------------------------------------------------
    if [[ $# -lt 1 ]]; then
        error "Usage: nds_runAsSudo <targetScript> [--ignore-case|-i] [--prefix|-p PREFIX ...]"
        return 1
    fi

    targetScript="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--ignore-case)
                ignoreCase="true"
                ;;
            -p|--prefix)
                shift
                [[ -z "${1:-}" ]] && { error "Missing value for --prefix"; return 1; }
                prefixes+=("$1")
                ;;
            *)
                # Forward any additional arguments to target script
                break
                ;;
        esac
        shift
    done

    # Remaining args go to the re-exec’d script
    local -a scriptArgs=("$@")

    # --- Root Check -------------------------------------------------------------
    if [[ $EUID -eq 0 ]]; then
        success "Root privileges confirmed"
        return 0
    fi

    new_section
    section_header "Root Privilege Required"
    warn "This script requires root privileges."
    info "Attempting to restart with sudo..."

    # --- Prefix Handling --------------------------------------------------------
    [[ ${#prefixes[@]} -eq 0 ]] && prefixes=("NDS_")

    # Enable case-insensitive matching if requested
    if [[ "$ignoreCase" == "true" ]]; then
        shopt -s nocasematch
    fi

    # --- Collect Environment Variables ------------------------------------------
    while IFS='=' read -r envLine; do
        name="${envLine%%=*}"
        value="${envLine#*=}"

        for prefix in "${prefixes[@]}"; do
            if [[ "$name" == ${prefix}* ]]; then
                preservedVars+=("${name}=${value}")
                break
            fi
        done
    done < <(env)

    [[ "$ignoreCase" == "true" ]] && shopt -u nocasematch

    # --- Re-exec via sudo -------------------------------------------------------
    if [[ ${#preservedVars[@]} -gt 0 ]]; then
        debug "Preserving variables: ${prefixes[*]}"
        exec sudo "${preservedVars[@]}" bash "$targetScript" "${scriptArgs[@]}"
    else
        exec sudo bash "$targetScript" "${scriptArgs[@]}"
    fi
}
