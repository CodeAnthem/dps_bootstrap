#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - User prompts and confirmations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-08-04
# Description:   Interactive yes/no/back prompts
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_PROMPTS_SKIP

# Description: True when a value is boolean true (true/1, case-insensitive).
# Arguments:
# - value: <String> Value to test
# Returns:
# - 0 when true, 1 otherwise
nds_env_is_true() {
    local value="${1:-}"
    [[ "${value,,}" == "true" || "$value" == "1" ]]
}

nds_ask_user_continue() {
    local prompt="${1:-Do you want to proceed?}"

    if nds_skip_menu NDS_PROMPTS_SKIP; then
        printf '%s%s [y/n/b]: y (skipped)\n' "$NDS_UI_INDENT_B" "$prompt" >&2
        return 0
    fi

    while true; do
        # -s: no echo of key; print the word on the same line as the prompt.
        read -rsp "${NDS_UI_INDENT_B}${prompt} [y/n/b]: " -n 1 confirm < /dev/tty
        case "${confirm,,}" in
            y)
                printf 'Yes\n' >&2
                return 0
                ;;
            n)
                printf 'No\n' >&2
                return 1
                ;;
            b)
                printf 'Back\n' >&2
                return 2
                ;;
            *)
                printf '\n' >&2
                nds_ui_b "Enter y (yes), n (no), or b (back)"
                ;;
        esac
    done
}

nds_ask_user_to_proceed() {
    local prompt="${1:-Do you want to proceed?}"

    if nds_skip_menu NDS_PROMPTS_SKIP; then
        printf '%s%s (y/n): y (skipped)\n' "$NDS_UI_INDENT_B" "$prompt" >&2
        return 0
    fi

    while true; do
        read -rsp "${NDS_UI_INDENT_B}${prompt} (y/n): " -n 1 confirm < /dev/tty
        case "${confirm,,}" in
            y)
                printf 'Yes\n' >&2
                return 0
                ;;
            n)
                printf 'No\n' >&2
                return 1
                ;;
            "")
                printf '\n' >&2
                continue
                ;;
            *)
                printf '\n' >&2
                nds_ui_b "Press y (yes) or n (no)"
                ;;
        esac
    done
}
