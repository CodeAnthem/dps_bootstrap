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
    echo "(yes/no, true/false, enabled/disabled)"
}

validate_toggle() {
    local value="$1"
    [[ "${value,,}" =~ ^(true|false|enabled|disabled|yes|no|y|n|1|0)$ ]]
}

normalize_toggle() {
    local value="$1"
    case "${value,,}" in
        true|enabled|yes|y|1) echo "true" ;;
        false|disabled|no|n|0) echo "false" ;;
    esac
}

display_toggle() {
    nds_ui_format_bool "$1"
}

error_msg_toggle() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Enter yes, no, true, false, enabled, or disabled"
}
