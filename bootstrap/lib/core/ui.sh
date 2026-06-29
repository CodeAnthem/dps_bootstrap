#!/usr/bin/env bash
# ==================================================================================================
# NDS - Terminal UI helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Terminal capability detection, colors, and two-column menu formatting
# ==================================================================================================

[[ -n "${_NDS_UI_SH_LOADED:-}" ]] && return 0
_NDS_UI_SH_LOADED=1

declare -g NDS_UI_MODE=""
declare -g NDS_UI_COLOR=false
declare -g NDS_UI_LABEL_WIDTH=38

# Return code: action_setup should return this to re-open the action menu.
readonly NDS_ACTION_BACK=10

# Description: Detect terminal capabilities and pick a display mode.
# Modes: plain (no color), color (ANSI + true/false), unicode (box drawing + symbols).
# Override with NDS_UI_MODE=plain|color|unicode or NDS_UI_MODE=auto (default).
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

# Description: Prefix string for log levels (emoji only in unicode mode).
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

# Description: Format boolean values for menus (true/false; optional ANSI color).
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

# Description: Print a label/value row for configuration menus.
nds_ui_kv_row() {
    local label="$1"
    local value="$2"
    local width="${3:-$NDS_UI_LABEL_WIDTH}"

    nds_ui_init

    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf "     \033[1m%-${width}s\033[0m %s\n" "${label}:" "$value" >&2
    else
        printf "     %-${width}s %s\n" "${label}:" "$value" >&2
    fi
}

# Description: Draw a titled box (unicode or ASCII depending on mode).
nds_ui_draw_box() {
    local title="$1"
    local length="${2:-50}"
    local inner_length=$((length - 2))
    local border

    nds_ui_init

    if [[ "$NDS_UI_MODE" == "unicode" ]]; then
        border=$(printf '─%.0s' $(seq 1 "$inner_length"))
        printf "╭%s╮\n" "$border" >&2
        printf "│%-*s│\n" "$inner_length" "$title" >&2
        printf "╰%s╯\n" "$border" >&2
        return 0
    fi

    border=$(printf -- '-%.0s' $(seq 1 "$inner_length"))
    printf "+%s+\n" "$border" >&2
    printf "|%-*s|\n" "$inner_length" "$title" >&2
    printf "+%s+\n" "$border" >&2
}

# Description: Step progress icons for step_start / step_complete / step_fail.
nds_ui_step_icon() {
    local state="$1"
    nds_ui_init
    if [[ "$NDS_UI_MODE" == "unicode" ]]; then
        case "$state" in
            start) echo "..." ;;
            ok) echo "[OK]" ;;
            fail) echo "[FAIL]" ;;
        esac
        return 0
    fi
    case "$state" in
        start) echo "..." ;;
        ok) echo "[OK]" ;;
        fail) echo "[FAIL]" ;;
    esac
}
