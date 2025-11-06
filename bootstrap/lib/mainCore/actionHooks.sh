#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Minimal hook registry for modular action scripts
# Feature:       Register and call optional hooks (per-name)
# ==================================================================================================

# Global associative map of hooks: name -> functionName
declare -gA NDS_HOOKS=()

# Register a hook function for a named hook
# Usage: nds_hook_register <hookName> <functionName>
nds_hook_register() {
    local hookName="$1"
    local functionName="$2"

    if [[ -z "$hookName" || -z "$functionName" ]]; then return 1; fi

    NDS_HOOKS["$hookName"]="$functionName"
    return 0
}

# Call a hook if registered. Any output from the hook function is echoed to stdout.
# Usage: nds_hook_call <hookName> [args...]
# Returns 0 if called successfully, 1 if hook not registered or function missing.
nds_hook_call() {
    local hookName="$1"
    shift || true
    local functionName="${NDS_HOOKS[$hookName]:-}"

    if [[ -z "$functionName" ]]; then return 1; fi
    if ! declare -f "$functionName" &>/dev/null; then return 1; fi

    "$functionName" "$@"
    return 0
}

# Check if a hook is registered
# Usage: nds_hook_exists <hookName>
nds_hook_exists() {
    local hookName="$1"
    [[ -n "${NDS_HOOKS[$hookName]:-}" ]]
}
