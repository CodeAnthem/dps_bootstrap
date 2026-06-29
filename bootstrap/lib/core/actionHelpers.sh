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

    console "$title"
    console ""
    console "  You will configure:"
    IFS=',' read -ra _items <<< "$youwill"
    for item in "${_items[@]}"; do
        console "    - $(nds_trim "$item")"
    done
    console ""
    console "  After confirmation, NDS will:"
    IFS=',' read -ra _items <<< "$ndswill"
    for item in "${_items[@]}"; do
        console "    - $(nds_trim "$item")"
    done
    console ""
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
        console "$prompt [y/n/b]: y (auto-confirmed)"
        return 0
    fi

    while true; do
        read -rsp "$prompt [y/n/b]: " -n 1 confirm < /dev/tty
        echo >&2
        case "${confirm,,}" in
            y)
                console "Yes"
                return 0
                ;;
            n)
                console "No"
                return 1
                ;;
            b)
                console "Back to action menu"
                return 2
                ;;
            *)
                console "Enter y (yes), n (no), or b (back)"
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
        console "$prompt (y/n): y (auto-confirmed)"
        return 0
    fi
    
    read -rsp "$prompt (y/n): " -n 1 confirm < /dev/tty
    if [[ "${confirm,,}" != "y" ]]; then
        console "No!"
        return 1
    fi
    
    console "Yes!"
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
