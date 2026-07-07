#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Terminal capabilities and layout
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
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

# Description: Read one menu digit without Enter (same UX as action select).
# Arguments:
# - prompt: <String> Prompt text
# - min:    <Int>    Minimum valid digit
# - max:    <Int>    Maximum valid digit
# Returns:
# - <String> Selected digit on stdout; 1 when user presses Enter only
nds_ui_read_menu_digit() {
    local prompt="$1" min="$2" max="$3"
    local choice

    nds_ui_init
    while true; do
        read -rsn1 -p "$prompt" choice < /dev/tty
        echo >&2
        [[ -n "$choice" ]] || return 1
        if [[ "$choice" =~ ^[0-9]$ ]] && (( choice >= min && choice <= max )); then
            printf '%s' "$choice"
            return 0
        fi
        nds_ui_b "Invalid selection. Choose ${min}-${max}."
    done
}

# Description: Render the persistent NDS banner as a single box containing the
# fixed script title line (name + version) and an optional section subtitle.
# The box width expands to fit the longest line, with a sane minimum. All lines
# share one left margin so corners and pipes align, and content is padded by
# character count (not bytes) so multibyte glyphs like the em dash stay square.
# Arguments:
# - subtitle: <String> Current section/screen name (may be empty)
nds_ui_banner() {
    local subtitle="${1:-}"
    local title_line=" === ${SCRIPT_NAME:-Nix Deploy System} v${SCRIPT_VERSION:-} === "
    local sub_line="  ${subtitle}"
    local inner=${#title_line}
    (( ${#sub_line} > inner )) && inner=${#sub_line}
    (( inner < 56 )) && inner=56

    nds_ui_init

    local margin='  '
    local border
    border=$(printf -- '-%.0s' $(seq 1 "$inner"))

    printf "%s+%s+\n" "$margin" "$border" >&2
    printf "%s|%s%*s|\n" "$margin" "$title_line" "$(( inner - ${#title_line} ))" '' >&2
    [[ -n "$subtitle" ]] && printf "%s|%s%*s|\n" "$margin" "$sub_line" "$(( inner - ${#sub_line} ))" '' >&2
    printf "%s+%s+\n" "$margin" "$border" >&2
}
