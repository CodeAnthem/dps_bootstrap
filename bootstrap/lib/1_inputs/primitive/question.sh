#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-10-23
# Description:   Input Handler - Question
# Feature:       Boolean question (yes/no) for confirmations
# ==================================================================================================

# =============================================================================
# QUESTION INPUT
# =============================================================================

prompt_hint_question() {
    echo "(yes/no)"
}

validate_question() {
    local value="$1"
    [[ "${value,,}" =~ ^(yes|no|y|n)$ ]]
}

normalize_question() {
    local value="$1"
    case "${value,,}" in
        yes|y) echo "yes" ;;
        no|n) echo "no" ;;
    esac
}

error_msg_question() {
    local value="$1"
    local code="${2:-0}"
    
    # Simple validator - only one failure mode
    echo "Enter yes or no"
}
