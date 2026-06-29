#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-10-29
# Description:   Generic action helper functions
# Feature:       Reusable utilities for action setup scripts
# ==================================================================================================

# =============================================================================
# ACTION OVERVIEW
# =============================================================================

# Description: Print a formatted action overview with a "You will" + "NDS will" list.
# Arguments:
# - title:   <String> Short action name shown as the heading
# - youwill: <String> Comma-separated list of things the user configures
# - ndswill: <String> Comma-separated list of steps NDS performs after confirm
# Returns:
# - Prints the overview to stderr
nds_action_overview() {
    local title="$1"
    local youwill="$2"
    local ndswill="$3"
    local item

    nds_ui_h "$title"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    IFS=',' read -ra _items <<< "$youwill"
    for item in "${_items[@]}"; do
        nds_ui_b "- $(nds_trim "$item")"
    done
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    IFS=',' read -ra _items <<< "$ndswill"
    for item in "${_items[@]}"; do
        nds_ui_b "- $(nds_trim "$item")"
    done
    nds_ui_b ""
}

# Description: Trim leading/trailing whitespace from a string.
nds_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# =============================================================================
# USER INTERACTION HELPERS
# =============================================================================

# Ask user to proceed with yes/no/back prompt.
# Usage: nds_askUserContinue ["custom prompt"]
# Returns: 0 yes, 1 no, 2 back to action menu
# Set NDS_AUTO_CONFIRM=true to auto-skip all prompts
nds_askUserContinue() {
    local prompt="${1:-Do you want to proceed?}"

    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        nds_ui_b "$prompt [y/n/b]: y (auto-confirmed)"
        return 0
    fi

    while true; do
        read -rsp "${NDS_UI_INDENT_B}${prompt} [y/n/b]: " -n 1 confirm < /dev/tty
        echo >&2
        case "${confirm,,}" in
            y)
                nds_ui_b "Yes"
                return 0
                ;;
            n)
                nds_ui_b "No"
                return 1
                ;;
            b)
                nds_ui_b "Back to action menu"
                return 2
                ;;
            *)
                nds_ui_b "Enter y (yes), n (no), or b (back)"
                ;;
        esac
    done
}

# Ask user to proceed with yes/no prompt
# Usage: nds_askUserToProceed ["custom prompt"]
# Returns: 0 if user confirmed, 1 if declined
# Set NDS_AUTO_CONFIRM=true to auto-skip all prompts
nds_askUserToProceed() {
    local prompt="${1:-Do you want to proceed?}"
    
    # Auto-confirm if NDS_AUTO_CONFIRM is set to true
    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        nds_ui_b "$prompt (y/n): y (auto-confirmed)"
        return 0
    fi

    read -rsp "${NDS_UI_INDENT_B}${prompt} (y/n): " -n 1 confirm < /dev/tty
    echo >&2
    if [[ "${confirm,,}" != "y" ]]; then
        nds_ui_b "No"
        return 1
    fi

    nds_ui_b "Yes"
    return 0
}

# Map nds_askUserContinue to action return codes (back → NDS_ACTION_BACK).
nds_askUserContinue_or_exit() {
    local prompt="${1:-Continue?}"
    nds_askUserContinue "$prompt" || {
        local rc=$?
        if [[ "$rc" -eq 2 ]]; then
            return "$NDS_ACTION_BACK"
        fi
        return 130
    }
}
