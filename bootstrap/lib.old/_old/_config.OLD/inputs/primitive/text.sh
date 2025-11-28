#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Input Handler - Text
# Feature:       Multi-line text input (for SSH keys, configs, etc.)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# TEXT INPUT
# ----------------------------------------------------------------------------------

prompt_hint_text() {
    echo "(multi-line text, press Ctrl+D when done)"
}

validate_text() {
    local value="$1"
    # Text input is always valid (even empty)
    return 0
}

normalize_text() {
    local value="$1"
    # No normalization needed
    echo "$value"
}

error_msg_text() {
    local value="$1"
    local code="${2:-0}"
    
    # Text input doesn't have errors
    echo ""
}
