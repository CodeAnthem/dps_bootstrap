#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       User input and interaction helper functions
# ==================================================================================================

# =============================================================================
# USER PROMPT FUNCTIONS
# =============================================================================

# Prompt for yes/no confirmation
# Usage: prompt_yes_no "question" [default_yes]
prompt_yes_no() {
    local prompt="$1"
    local default_yes="${2:-false}"
    local response
    
    # Read from terminal directly to avoid stdin pollution
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -rp "$prompt [y/N]: " response < /dev/tty
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            echo "$prompt [y/N]: "
            read -r response < /dev/tty || {
                if [[ "$default_yes" == "true" ]]; then
                    echo "No input received, assuming 'yes'"
                    return 0
                else
                    echo "No input received, assuming 'no'"
                    return 1
                fi
            }
        else
            # No TTY available, use default
            if [[ "$default_yes" == "true" ]]; then
                echo "No interactive terminal available, assuming 'yes'"
                return 0
            else
                echo "No interactive terminal available, assuming 'no'"
                return 1
            fi
        fi
    fi
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]|"") return 1 ;;
        *) 
            echo "Invalid response '$response', assuming 'no'"
            return 1 ;;
    esac
}

# Prompt for password with confirmation
# Usage: prompt_password "prompt text"
prompt_password() {
    local prompt="$1"
    local password
    local confirm_password
    
    while true; do
        read -rsp "$prompt: " password < /dev/tty
        echo
        read -rsp "Confirm $prompt: " confirm_password < /dev/tty
        echo
        
        if [[ "$password" == "$confirm_password" ]]; then
            echo "$password"
            return 0
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

# Prompt for GitHub token
# Usage: github_token=$(prompt_github_token)
prompt_github_token() {
    local token
    
    echo >&2
    echo "=== GitHub Token Required ===" >&2
    echo "A GitHub token is needed to clone your private NixOS flake repository." >&2
    echo "You can create one at: https://github.com/settings/tokens" >&2
    echo "Required permissions: repo (full repository access)" >&2
    echo >&2
    
    # Read from terminal directly to avoid stdin pollution
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -rsp "Enter GitHub token (or press Enter to skip): " token < /dev/tty
        echo
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            echo "Enter GitHub token (or press Enter to skip): " >&2
            read -rs token < /dev/tty || {
                echo "No input received, skipping token" >&2
                token=""
            }
            echo >&2
        else
            # No TTY available, skip token
            echo "No interactive terminal available, skipping token" >&2
            token=""
        fi
    fi
    
    if [[ -n "$token" ]]; then
        echo "✅ Token received (hidden for security)" >&2
    else
        echo "⚠️  No token provided - you'll need to set up repository access manually" >&2
    fi
    
    # ONLY return the token, send messages to stderr
    printf '%s' "$token"
}

# =============================================================================
# NIX SHELL WRAPPER
# =============================================================================

# Execute command in nix-shell environment
# Usage: with_nix_shell "packages" "command"
with_nix_shell() {
    local packages="$1"
    shift
    debug "Running with nix-shell packages: $packages"
    nix-shell -p $packages --run "$*"
}
