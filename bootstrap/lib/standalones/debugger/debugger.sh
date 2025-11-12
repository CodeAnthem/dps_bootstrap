#!/usr/bin/env bash
# ==================================================================================================
# Debugger - Standalone Feature
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-12
# Description:   Conditional debug output with dynamic variable name support
# Feature:       Enable/disable debug, check state, custom debug variable name
# ==================================================================================================

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
# Get debug variable name from first argument (default: DEBUG)
declare -g __DEBUG_VAR_NAME="${1:-DEBUG}"

# Initialize the debug variable (0=disabled, 1=enabled)
# Default to disabled (0) - environment can override via string values later
declare -g "$__DEBUG_VAR_NAME=0"

# Initialize debug configuration
declare -gA __DEBUG_CFG=(
    [output_file]=""
    [use_timestamp]=1
    [use_datestamp]=1
    [emoji]=" 🚧"
    [tag]=" [DEBUG] -"
    [indent]=1
)


# ==================================================================================================
# PUBLIC FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Print debug message (dynamically generated)
# Usage: debug <message>
debug() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Enable debug output (with optional silent mode)
# Usage: debug_enable [silent]
debug_enable() { debug_state 1 "${1:-}"; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Disable debug output (with optional silent mode)
# Usage: debug_disable [silent]
debug_disable() { debug_state 0 "${1:-}"; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Toggle debug state
# Usage: debug_toggle [silent]
debug_toggle() {
    if [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]; then
        debug_state 0 "${1:-}"
    else
        debug_state 1 "${1:-}"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set debug state
# Usage: debug_state state [silent]
debug_state() {
    local value silent
    value="${1:-}"
    silent="${2:-}"
    case "$value" in
        true|1|on|enabled)
            if [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]; then
                [[ -n "${silent}" ]] || debug "Debug already enabled"
                return 0
            fi
            declare -g "$__DEBUG_VAR_NAME=1"
            __debug_defineFN
            [[ -z "${silent}" ]] && debug "Debug enabled"
        ;;
        false|0|off|disabled)
            if [[ "${!__DEBUG_VAR_NAME}" -eq 0 ]]; then
                [[ -n "${silent}" ]] || debug "Debug already disabled"
                return 0
            fi
            declare -g "$__DEBUG_VAR_NAME=0"
            __debug_defineFN
            [[ -z "${silent}" ]] && debug "Debug disabled"
        ;;
        *)
            echo "Wrong usage of debug_state() function" >&2
            echo " -> Usage: debug_state <state> [silent]" >&2
            echo " -> State: true|1|on|enabled or false|0|off|disabled" >&2
            echo " -> Silent: any value to suppress output" >&2
            return 1
        ;;
    esac
    return 0
}
# --------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------
# Public: Consolidated setter for debug options with argument parsing
# Usage: debug_set [options]
# Options:
#   --file PATH           Set output file path (directory must exist or be creatable)
#   --timestamp BOOL      Enable/disable timestamp (1/0, true/false, on/off)
#   --datestamp BOOL      Enable/disable datestamp (1/0, true/false, on/off)
#   --emoji STRING        Set emoji prefix
#   --tag STRING          Set tag prefix
#   --indent NUMBER       Set number of leading spaces (must be >= 0)
# Example: debug_set --file "./debug.log" --timestamp 0 --indent 3
debug_set() {
    local needs_reinit=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file|--output)
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
                __DEBUG_CFG[output_file]="$value"
                needs_reinit=1
                shift 2
                ;;
            --timestamp)
                [[ -z "${2:-}" ]] && { echo "Error: --timestamp requires a value" >&2; return 1; }
                case "$2" in
                    1|true|on|enabled) __DEBUG_CFG[use_timestamp]=1 ;;
                    0|false|off|disabled) __DEBUG_CFG[use_timestamp]=0 ;;
                    *) echo "Error: Invalid --timestamp value '$2' (use: 1/0, true/false, on/off)" >&2; return 1 ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            --datestamp)
                [[ -z "${2:-}" ]] && { echo "Error: --datestamp requires a value" >&2; return 1; }
                case "$2" in
                    1|true|on|enabled) __DEBUG_CFG[use_datestamp]=1 ;;
                    0|false|off|disabled) __DEBUG_CFG[use_datestamp]=0 ;;
                    *) echo "Error: Invalid --datestamp value '$2' (use: 1/0, true/false, on/off)" >&2; return 1 ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            --emoji)
                [[ -z "${2:-}" ]] && { echo "Error: --emoji requires a value" >&2; return 1; }
                __DEBUG_CFG[emoji]="$2"
                needs_reinit=1
                shift 2
                ;;
            --tag)
                [[ -z "${2:-}" ]] && { echo "Error: --tag requires a value" >&2; return 1; }
                __DEBUG_CFG[tag]="$2"
                needs_reinit=1
                shift 2
                ;;
            --indent)
                [[ -z "${2:-}" ]] && { echo "Error: --indent requires a value" >&2; return 1; }
                if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                    echo "Error: Invalid --indent value '$2' (must be a number >= 0)" >&2
                    return 1
                fi
                __DEBUG_CFG[indent]="$2"
                needs_reinit=1
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Usage: debug_set [options]" >&2
                echo "Options: --file PATH, --timestamp BOOL, --datestamp BOOL," >&2
                echo "         --emoji STRING, --tag STRING, --indent NUMBER" >&2
                return 1
                ;;
        esac
    done

    # Only reinitialize once after all changes
    [[ $needs_reinit -eq 1 ]] && __debug_defineFN
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current debug variable name
# Usage: var_name=$(debug_get_var_name)
debug_get_var_name() { echo "$__DEBUG_VAR_NAME"; }
# --------------------------------------------------------------------------------------------------


# ==================================================================================================
# INTERNAL FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Internal: Define debug functions
# Usage: __debug_defineFN
__debug_defineFN() {
    # Define debug_is_enabled and debug_get_state
    if [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]; then
        # Enabled: no checks needed
        source /dev/stdin <<<'debug_is_enabled() { return 0; }'
        source /dev/stdin <<<'debug_get_state() { echo "enabled"; }'
    else
        # Disabled: always return failure
        source /dev/stdin <<<'debug_is_enabled() { return 1; }'
        source /dev/stdin <<<'debug_get_state() { echo "disabled"; }'
    fi

    # Define debug function
    __debug_defineFN_debug
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Internal: Initialize debug function based on current format settings
# Usage: __debug_defineFN_debug
# Note: Called by __debug_defineFN_status and debug_set
__debug_defineFN_debug() {
    local var_name indent_str ts_fmt fmt_str ts_arg

    var_name="$__DEBUG_VAR_NAME"

    # Build indent
    printf -v indent_str '%*s' "${__DEBUG_CFG[indent]}" ''

    # Build timestamp format (no trailing \n - printf will handle that)
    if [[ ${__DEBUG_CFG[use_timestamp]} -eq 1 ]]; then
        if [[ ${__DEBUG_CFG[use_datestamp]} -eq 1 ]]; then
            ts_fmt='%(%Y-%m-%d %H:%M:%S)T'
            ts_arg='"-1" '
        else
            ts_fmt='%(%H:%M:%S)T'
            ts_arg='"-1" '
        fi
    else
        ts_fmt=''
        ts_arg=''
    fi

    # Build complete format string (no \n - we use printf %s later)
    fmt_str="${indent_str}${ts_fmt}%s%s %s"

    # Generate state-based debug function (using source /dev/stdin, NO eval)
    if [[ "${!var_name}" -eq 1 ]]; then
        # Enabled: build output and send to destinations
        if [[ -n "${__DEBUG_CFG[output_file]}" ]]; then
            # With file output
            source /dev/stdin <<- EOF
            debug() {
                local o
                printf -v o "$fmt_str" ${ts_arg}"${__DEBUG_CFG[emoji]}" "${__DEBUG_CFG[tag]}" "\$1"
                printf '%s\\n' "\$o" >&2
                printf '%s\\n' "\$o" >> "${__DEBUG_CFG[output_file]}"
            }
EOF
        else
            # Console only
            source /dev/stdin <<- EOF
            debug() {
                local o
                printf -v o "$fmt_str" ${ts_arg}"${__DEBUG_CFG[emoji]}" "${__DEBUG_CFG[tag]}" "\$1"
                printf '%s\\n' "\$o" >&2
            }
EOF
        fi
    else
        # Disabled: no-op
        source /dev/stdin <<<'debug() { :; }'
    fi
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# AUTO-INITIALIZATION
# ==================================================================================================

# If the debug variable is set to "true" or "false" string, convert to 1/0
if [[ "${!__DEBUG_VAR_NAME}" == "true" ]]; then
    declare -g "$__DEBUG_VAR_NAME=1"
elif [[ "${!__DEBUG_VAR_NAME}" == "false" ]]; then
    declare -g "$__DEBUG_VAR_NAME=0"
fi

# Initialize all functions based on current state
__debug_defineFN
