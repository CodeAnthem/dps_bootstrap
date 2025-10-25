#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Toggle
# Feature:       Boolean toggle (true/false, enabled/disabled)
# ==================================================================================================

# =============================================================================
# TOGGLE INPUT
# =============================================================================

prompt_hint_toggle() {
    echo "(true/false, enabled/disabled)"
}

validate_toggle() {
    local value="$1"
    [[ "${value,,}" =~ ^(true|false|enabled|disabled|1|0)$ ]]
}

normalize_toggle() {
    local value="$1"
    case "${value,,}" in
        true|enabled|1) echo "✓" ;;
        false|disabled|0) echo "✗" ;;
    esac
}

error_msg_toggle() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Enter true, false, enabled, or disabled"
}
