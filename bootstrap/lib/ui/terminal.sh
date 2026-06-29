#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Terminal capabilities and layout
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Terminal mode detection, indentation, boxes, columns, boolean display
# ==================================================================================================

declare -g NDS_UI_MODE=""
declare -g NDS_UI_COLOR=false
declare -g NDS_UI_LABEL_WIDTH=38
declare -g NDS_UI_INDENT_H=' '
declare -g NDS_UI_INDENT_B='  '
declare -g NDS_UI_INDENT_I='    '

readonly NDS_ACTION_BACK=10

nds_ui_h() {
    printf '%s%s\n' "$NDS_UI_INDENT_H" "${1:-}" >&2
}

nds_ui_b() {
    printf '%s%s\n' "$NDS_UI_INDENT_B" "${1:-}" >&2
}

nds_ui_i() {
    printf '%s%s\n' "$NDS_UI_INDENT_I" "${1:-}" >&2
}

nds_ui_init() {
    [[ -n "${NDS_UI_INIT_DONE:-}" ]] && return 0
    NDS_UI_INIT_DONE=1

    local mode="${NDS_UI_MODE:-auto}"
    NDS_UI_COLOR=false

    if [[ "$mode" == "auto" ]]; then
        if [[ ! -t 2 ]] || [[ "${TERM:-}" == "dumb" ]]; then
            mode=plain
        elif [[ -n "${NO_COLOR:-}" ]]; then
            mode=plain
        elif command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
            mode=color
        else
            mode=plain
        fi
    fi

    if [[ "$mode" == "unicode" ]] && { [[ ! -t 2 ]] || [[ "${TERM:-}" == "dumb" ]]; }; then
        mode=plain
    fi

    if [[ "$mode" != "plain" ]] && [[ -z "${NO_COLOR:-}" ]] \
        && command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
        NDS_UI_COLOR=true
    fi

    NDS_UI_MODE="$mode"
}

nds_ui_log_tag() {
    local level="$1"
    nds_ui_init
    if [[ "$NDS_UI_MODE" == "unicode" ]]; then
        case "$level" in
            info) echo "ℹ️  [INFO] -" ;;
            success) echo "✅ [PASS] -" ;;
            warn) echo "⚠️  [WARN] -" ;;
            error) echo "❌ [FAIL] -" ;;
            fatal) echo "❌ [FATAL] -" ;;
            debug) echo "🐛 [DEBUG] -" ;;
            validation) echo "❌ [VALIDATION] - " ;;
            *) echo "[LOG] -" ;;
        esac
        return 0
    fi
    case "$level" in
        info) echo "[INFO] -" ;;
        success) echo "[OK] -" ;;
        warn) echo "[WARN] -" ;;
        error) echo "[FAIL] -" ;;
        fatal) echo "[FATAL] -" ;;
        debug) echo "[DEBUG] -" ;;
        validation) echo "[VALIDATION] - " ;;
        *) echo "[LOG] -" ;;
    esac
}

nds_ui_format_bool() {
    local value="$1"
    local text

    nds_ui_init

    case "$value" in
        true) text=true ;;
        false) text=false ;;
        *) echo "$value"; return 0 ;;
    esac

    if [[ "$NDS_UI_MODE" == "unicode" ]]; then
        case "$value" in
            true) text=yes ;;
            false) text=no ;;
        esac
    fi

    if [[ "$NDS_UI_COLOR" == true ]]; then
        if [[ "$value" == true ]]; then
            printf '\033[32m%s\033[0m' "$text"
        else
            printf '\033[90m%s\033[0m' "$text"
        fi
        return 0
    fi

    echo "$text"
}

nds_ui_kv_row() {
    local label="$1"
    local value="$2"
    local width="${3:-$NDS_UI_LABEL_WIDTH}"

    nds_ui_init

    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf "%s\033[1m%-${width}s\033[0m %s\n" "$NDS_UI_INDENT_I" "${label}:" "$value" >&2
    else
        printf "%s%-${width}s %s\n" "$NDS_UI_INDENT_I" "${label}:" "$value" >&2
    fi
}

nds_ui_choice_row() {
    local number="$1"
    local name="$2"
    local detail="$3"
    local width="${4:-26}"

    nds_ui_kv_row "${number}) ${name}" "$detail" "$width"
}

nds_ui_draw_box() {
    local title="$1"
    local length="${2:-0}"
    local inner_length border

    nds_ui_init

    if [[ "$length" -le 0 ]]; then
        length=$(( ${#title} + 2 ))
        (( length < 42 )) && length=42
    fi
    inner_length=$((length - 2))

    if [[ "$NDS_UI_MODE" == "unicode" ]]; then
        border=$(printf '─%.0s' $(seq 1 "$inner_length"))
        printf "%s╭%s╮\n" "$NDS_UI_INDENT_H" "$border" >&2
        printf "%s│%-*s│\n" "$NDS_UI_INDENT_H" "$inner_length" "$title" >&2
        printf "%s╰%s╯\n" "$NDS_UI_INDENT_H" "$border" >&2
        return 0
    fi

    border=$(printf -- '-%.0s' $(seq 1 "$inner_length"))
    printf "%s+%s+\n" "$NDS_UI_INDENT_H" "$border" >&2
    printf "%s|%-*s|\n" "$NDS_UI_INDENT_H" "$inner_length" "$title" >&2
    printf "%s+%s+\n" "$NDS_UI_INDENT_H" "$border" >&2
}
