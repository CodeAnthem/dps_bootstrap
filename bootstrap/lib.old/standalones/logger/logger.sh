#!/usr/bin/env bash
# ==================================================================================================
# Logger - Standalone Feature
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-13
# Description:   Dynamic logging system with multiple levels and optional file output
# Feature:       Dynamic logger creation, file logging, exit codes, emoji suppression
# ==================================================================================================
# shellcheck disable=SC1091  # Source not following

# ==================================================================================================
# VALIDATION & INITIALIZATION
# ==================================================================================================
# Prevent execution - this file must be sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed" >&2
    echo "Usage: source ${BASH_SOURCE[0]}" >&2
    exit 1
fi


# ==================================================================================================
# GLOBAL VARIABLES - Configuration (using associative array to avoid pollution)
# ==================================================================================================

# Global configuration
declare -gA __LOG_CFG=(
    [output_file]=""
    [use_timestamp]=1
    [use_datestamp]=1
    [indent]=1
    [suppress_emojis]=0
)

# Logger registry: stores all registered loggers
# Format: [function_name]="emoji:tag:exit_code"
declare -gA __LOG_REGISTRY=()

# ==================================================================================================
# PUBLIC FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Consolidated setter for logger options with argument parsing
# Usage: log_set [options]
# Options:
#   --file PATH           Set output file path (directory must exist or be creatable)
#   --timestamp BOOL      Enable/disable timestamp (1/0, true/false, on/off)
#   --datestamp BOOL      Enable/disable datestamp (1/0, true/false, on/off)
#   --indent NUMBER       Set number of leading spaces (must be >= 0)
#   --suppress-emojis BOOL  Globally suppress emojis (1/0, true/false, on/off)
# Example: log_set --file "./app.log" --timestamp 0 --indent 3
log_set() {
    local needs_reinit=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file|--output)
                # Disable file output if no value is provided
                if [[ -z "${2:-}" ]] && [[ -n "${__LOG_CFG[output_file]}" ]]; then
                    __LOG_CFG[output_file]=""
                    needs_reinit=1
                    shift 2
                    return 0
                fi

                [[ -z "${2:-}" ]] && { echo "Error: --file requires a value" >&2; return 1; }
                local value="$2"
                if [[ -n "$value" ]]; then
                    # Validate path - directory must exist or be creatable
                    local dir
                    dir="$(dirname "$value")" || { echo "Error: Invalid file path '$value'" >&2; return 1; }
                    if [[ ! -d "$dir" ]]; then
                        mkdir -p "$dir" 2>/dev/null || {
                            echo "Error: Cannot create directory: $dir" >&2
                            return 1
                        }
                    fi
                    # Don't create file yet - will be created on first write
                fi
                __LOG_CFG[output_file]="$value"
                needs_reinit=1
                shift 2
                ;;
            --timestamp)
                case "${2:-}" in
                    1|true|on|enabled) __LOG_CFG[use_timestamp]=1 ;;
                    0|false|off|disabled) __LOG_CFG[use_timestamp]=0 ;;
                    *) echo "Error: Invalid --timestamp value '${2:-}' (use: 1/0, true/false, on/off)" >&2; return 1 ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            --datestamp)
                case "${2:-}" in
                    1|true|on|enabled) __LOG_CFG[use_datestamp]=1 ;;
                    0|false|off|disabled) __LOG_CFG[use_datestamp]=0 ;;
                    *) echo "Error: Invalid --datestamp value '${2:-}' (use: 1/0, true/false, on/off)" >&2; return 1 ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            --indent)
                [[ -z "${2:-}" ]] && { echo "Error: --indent requires a value" >&2; return 1; }
                if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                    echo "Error: Invalid --indent value '$2' (must be a number >= 0)" >&2
                    return 1
                fi
                __LOG_CFG[indent]="$2"
                needs_reinit=1
                shift 2
                ;;
            --suppress-emojis)
                case "${2:-}" in
                    1|true|on|enabled) __LOG_CFG[suppress_emojis]=1 ;;
                    0|false|off|disabled) __LOG_CFG[suppress_emojis]=0 ;;
                    *) echo "Error: Invalid --suppress-emojis value '${2:-}' (use: 1/0, true/false, on/off)" >&2; return 1 ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Usage: log_set [options]" >&2
                echo "Options: --file PATH, --timestamp BOOL, --datestamp BOOL," >&2
                echo "         --indent NUMBER, --suppress-emojis BOOL" >&2
                return 1
                ;;
        esac
    done

    # Only reinitialize once after all changes
    [[ $needs_reinit -eq 1 ]] && __log_defineFN
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Create/register a new logger function
# Usage: log_create_logger <name> [--emoji EMOJI] [--tag TAG] [--exit EXIT_CODE]
# Example: log_create_logger "critical" --emoji " 🔥" --tag " [CRITICAL] -" --exit 99
log_create_logger() {
    local name="$1"
    [[ -z "$name" ]] && { echo "Error: Logger name required" >&2; return 1; }
    shift

    local emoji=" 📝" tag=" [$name] -" exit_code="-1"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --emoji) emoji="${2:-}"; shift 2 ;;
            --tag) tag="${2:-}"; shift 2 ;;
            --exit)
                [[ ! "${2:-}" =~ ^-?[0-9]+$ ]] && { echo "Error: --exit must be a number" >&2; return 1; }
                exit_code="$2"
                shift 2
                ;;
            *) echo "Error: Unknown option '$1'" >&2; return 1 ;;
        esac
    done

    # Register logger
    __LOG_REGISTRY[$name]="$emoji:$tag:$exit_code"

    # Regenerate all functions
    __log_defineFN
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current log output file path
# Usage: file=$(log_get_file)
log_get_file() { echo "${__LOG_CFG[output_file]}"; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Display contents of current log file
# Usage: log_show_file
log_show_file() {
    if [[ -z "${__LOG_CFG[output_file]}" ]]; then
        echo "Error: No log output file configured" >&2
        return 1
    fi

    if [[ ! -f "${__LOG_CFG[output_file]}" ]]; then
        echo "Error: Log file does not exist: ${__LOG_CFG[output_file]}" >&2
        return 1
    fi

    cat "${__LOG_CFG[output_file]}"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Clear log file
# Usage: log_clear_file
log_clear_file() {
    if [[ -z "${__LOG_CFG[output_file]}" ]]; then
        echo "Error: No log output file configured" >&2
        return 1
    fi

    if [[ -f "${__LOG_CFG[output_file]}" ]]; then
        : > "${__LOG_CFG[output_file]}"
        echo " ℹ️  [INFO] - Log file cleared: ${__LOG_CFG[output_file]}" >&2
    else
        echo "Warning: Log file does not exist: ${__LOG_CFG[output_file]}" >&2
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Simple console output (no timestamp, no prefix)
# Usage: console <message>
console() { printf "%s\n" "${1:-}" >&2; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Formatted console output (no timestamp, no prefix)
# Usage: consolef <format> [args...]
consolef() { printf "%s\n" "${1:-}" "${@:2}" >&2; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Print newline to stderr
# Usage: new_line
new_line() { printf "\n" >&2; }
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# INTERNAL FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Internal: Define all logger functions
# Usage: __log_defineFN
__log_defineFN() {
    # Iterate through registry and create each function
    for func_name in "${!__LOG_REGISTRY[@]}"; do
        __log_defineFN_single "$func_name"
    done
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Internal: Initialize single logger function based on current format settings
# Usage: __log_defineFN_single <function_name>
__log_defineFN_single() {
    local func_name="$1"
    local spec="${__LOG_REGISTRY[$func_name]}"

    # Parse spec: emoji:tag:exit_code
    local emoji tag exit_code
    IFS=: read -r emoji tag exit_code <<< "$spec"

    # Check if we use emojis
    [[ ${__LOG_CFG[suppress_emojis]} -eq 1 ]] && emoji=""

    # Check if we exit
    local ifExit=""
    [[ "$exit_code" == "-1" ]] || ifExit="exit $exit_code;"

    # Build default message
    local fmt_msg="\${1:-\"<No message was passed> - called from \${FUNCNAME[1]}#\${BASH_LINENO[0]} in \${BASH_SOURCE[1]}\"}"

    # Build timestamp format
    local ts_arg fmt_str
    if [[ ${__LOG_CFG[use_timestamp]} -eq 1 ]]; then
        ts_arg='-1 '
        if [[ ${__LOG_CFG[use_datestamp]} -eq 1 ]]; then
            printf -v fmt_str '%*s%s%s%s' "${__LOG_CFG[indent]}" '' "%(%Y-%m-%d %H:%M:%S)T " "$emoji" "$tag"
        else
            printf -v fmt_str '%*s%s%s%s' "${__LOG_CFG[indent]}" '' "%(%H:%M:%S)T " "$emoji" "$tag"
        fi
    else
        printf -v fmt_str '%*s%s%s%s' "${__LOG_CFG[indent]}" '' '' "$emoji" "$tag"
    fi

    # Generate logger function (using source /dev/stdin, NO eval)
    if [[ -n "${__LOG_CFG[output_file]}" ]]; then
        # shellcheck disable=SC2154
        source /dev/stdin <<- EOF
        $func_name() {
            printf -v o '$fmt_str %s\\n' $ts_arg "$fmt_msg"
            echo "\$o" >&2
            echo "\$o" >> "${__LOG_CFG[output_file]}"
            $ifExit
        }
EOF
    else
        # Console only
        source /dev/stdin <<<"$func_name() { printf '$fmt_str %s\\n' $ts_arg \"$fmt_msg\" >&2; $ifExit }"
    fi
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# PRE-DEFINED LOGGERS & AUTO-INITIALIZATION
# ==================================================================================================

# Register predefined loggers
__LOG_REGISTRY[info]="ℹ️  :[INFO] -:-1"
__LOG_REGISTRY[warn]="⚠️  :[WARN] -:-1"
__LOG_REGISTRY[error]="💥 :[ERROR] -:-1"
__LOG_REGISTRY[fatal]="💀  :[FATAL] -:1"
__LOG_REGISTRY[pass]="✅  :[PASS] -:-1"
__LOG_REGISTRY[fail]="❌  :[FAIL] -:-1"

# Initialize all logging functions based on current settings

__log_defineFN
