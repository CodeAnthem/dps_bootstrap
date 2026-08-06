#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - User prompts and menu input
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-08-06
# Description:   Interactive yes/no/back and numbered-menu prompts
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_PROMPTS_SKIP

# Description: True when a value is boolean true (true/1, case-insensitive).
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

# Description: Build a standardized numbered-menu prompt line.
# Arguments:
# - min:         <Int> Minimum valid digit
# - max:         <Int> Maximum valid digit
# - default_opt: <String|optional> Default option key shown in brackets
# - text:        <String|optional> Prompt text
# - allow_back:  <Bool|optional> When true, show 0=back
nds_ui_numbered_prompt() {
    local min="$1" max="$2" default_opt="${3:-}" text="${4:-Make your selection}" allow_back="${5:-false}"

    nds_ui_init
    if [[ "$allow_back" == "true" ]]; then
        if [[ -n "$default_opt" ]]; then
            printf '%s%s [%s] (%s-%s, 0=back): ' "$NDS_UI_INDENT_I" "$text" "$default_opt" "$min" "$max"
        else
            printf '%s%s (%s-%s, 0=back): ' "$NDS_UI_INDENT_I" "$text" "$min" "$max"
        fi
    elif [[ -n "$default_opt" ]]; then
        printf '%s%s [%s] (%s-%s): ' "$NDS_UI_INDENT_I" "$text" "$default_opt" "$min" "$max"
    else
        printf '%s%s (%s-%s): ' "$NDS_UI_INDENT_I" "$text" "$min" "$max"
    fi
}

# Description: Read one menu digit without Enter.
# Arguments:
# - prompt:     <String> Prompt text
# - min:        <Int> Minimum valid digit
# - max:        <Int> Maximum valid digit
# - allow_back: <Bool|optional> When true, 0 or b returns "0"
nds_ui_read_menu_digit() {
    local prompt="$1" min="$2" max="$3" allow_back="${4:-false}"
    local choice

    nds_ui_init
    while true; do
        read -rsn1 -p "$prompt" choice < /dev/tty
        echo >&2
        [[ -n "$choice" ]] || return 1
        if [[ "$allow_back" == "true" ]] && [[ "$choice" == "0" || "$choice" == "b" || "$choice" == "B" ]]; then
            printf '0'
            return 0
        fi
        if [[ "$choice" =~ ^[0-9]$ ]] && (( choice >= min && choice <= max )); then
            printf '%s' "$choice"
            return 0
        fi
        if [[ "$allow_back" == "true" ]]; then
            nds_ui_b "Invalid selection. Choose ${min}-${max}, or 0 to go back."
        else
            nds_ui_b "Invalid selection. Choose ${min}-${max}."
        fi
    done
}
