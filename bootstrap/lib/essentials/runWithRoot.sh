#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Ensure script runs as root; optionally re-exec via sudo preserving selected env vars
# Feature:       Root elevation helper with variable prefix preservation
# ==================================================================================================

# Public: Ensure script runs with root privileges. If not, re-exec via sudo preserving matching env vars.
# Usage: nds_runWithRoot [prefix1 prefix2 ...]
# Example: nds_runWithRoot NDS_ DPS_
# Notes:
#   - Matching is case-sensitive by default.
nds_runWithRoot() {
    local -a prefixes=("$@")
    local prefix name value envLine
    local -a preservedVars=()

    # Already root? nothing to do
    if [[ $EUID -eq 0 ]]; then
        success "Root privileges confirmed"
        return 0
    fi

    # Info
    new_section
    section_header "Root Privilege Required"
    warn "This script requires root privileges."
    info "Attempting to restart with sudo..."

    # Preserve selected environment variables
    if [[ ${#prefixes[@]} -gt 0 ]]; then
        # Case-insensitive matching (optional, uncomment to enable)
        # shopt -s nocasematch

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

        # shopt -u nocasematch  # disable again if you enabled above
    fi

    # Re-exec with sudo, preserving selected variables
    if [[ ${#preservedVars[@]} -gt 0 ]]; then
        exec sudo "${preservedVars[@]}" bash "${BASH_SOURCE[0]}" "$@"
    else
        exec sudo bash "${BASH_SOURCE[0]}" "$@"
    fi
}
