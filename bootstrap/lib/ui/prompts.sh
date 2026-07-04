#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - User prompts and confirmations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-06-29
# Description:   Interactive yes/no/back prompts and legacy password helpers
# ==================================================================================================

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

nds_askUserToProceed() {
    local prompt="${1:-Do you want to proceed?}"

    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        nds_ui_b "$prompt (y/n): y (auto-confirmed)"
        return 0
    fi

    while true; do
        read -rsp "${NDS_UI_INDENT_B}${prompt} (y/n): " -n 1 confirm < /dev/tty
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
            "")
                continue
                ;;
            *)
                nds_ui_b "Press y (yes) or n (no)"
                ;;
        esac
    done
}

nds_askUserContinue_or_exit() {
    local prompt="${1:-Continue?}"
    nds_askUserContinue "$prompt"
    local rc=$?
    case "$rc" in
        0) return 0 ;;
        2) return "$NDS_ACTION_BACK" ;;
        *) return 130 ;;
    esac
}

prompt_yes_no() {
    local prompt="$1"
    local default_yes="${2:-false}"
    local response

    if [[ -t 0 ]]; then
        read -rp "$prompt [y/N]: " response < /dev/tty
    elif [[ -c /dev/tty ]]; then
        nds_ui_b "$prompt [y/N]:"
        read -r response < /dev/tty || {
            if [[ "$default_yes" == "true" ]]; then
                nds_ui_b "No input received, assuming yes"
                return 0
            fi
            nds_ui_b "No input received, assuming no"
            return 1
        }
    else
        if [[ "$default_yes" == "true" ]]; then
            nds_ui_b "No interactive terminal available, assuming yes"
            return 0
        fi
        nds_ui_b "No interactive terminal available, assuming no"
        return 1
    fi

    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]|"") return 1 ;;
        *)
            nds_ui_b "Invalid response '$response', assuming no"
            return 1
            ;;
    esac
}

prompt_password() {
    local prompt="$1"
    local password
    local confirm_password

    while true; do
        read -rsp "${NDS_UI_INDENT_B}${prompt}: " password < /dev/tty
        echo >&2
        read -rsp "${NDS_UI_INDENT_B}Confirm ${prompt}: " confirm_password < /dev/tty
        echo >&2

        if [[ "$password" == "$confirm_password" ]]; then
            echo "$password"
            return 0
        fi
        nds_ui_b "Passwords do not match. Please try again."
    done
}
