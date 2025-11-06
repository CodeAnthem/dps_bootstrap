#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Lightweight argument helpers for entry scripts
# Feature:       Check for presence of flags and extract key=value style values
# ==================================================================================================

# Usage: nds_arg_has <flag> [args...]
# Returns 0 if the flag is present in the supplied args.
nds_arg_has() {
    local search="$1"
    shift || true
    local arg
    for arg in "$@"; do
        [[ "$arg" == "$search" ]] && return 0
    done
    return 1
}

# Usage: nds_arg_value <key> [args...]
# Looks for key=value entries and echoes the value if found.
nds_arg_value() {
    local key="$1"
    shift || true
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "$key="* ]]; then
            echo "${arg#*=}"
            return 0
        fi
    done
    return 1
}
