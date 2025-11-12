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
# ARGUMENT PROCESSING
# ==================================================================================================

# Get debug variable name from first argument (default: DEBUG)
declare -g __DEBUG_VAR_NAME="${1:-DEBUG}"

# Initialize the debug variable (0=disabled, 1=enabled)
# Default to disabled (0) - environment can override via string values later
declare -g "$__DEBUG_VAR_NAME=0"

# ==================================================================================================
# GLOBAL VARIABLES - Configuration
# ==================================================================================================

declare -g __DEBUG_OUTPUT_FILE=""                             # Optional file path for debug output
declare -g __DEBUG_USE_TIMESTAMP=1                            # Show timestamp (1=yes, 0=no)
declare -g __DEBUG_USE_DATESTAMP=1                            # Show date in timestamp (1=yes, 0=no)
declare -g __DEBUG_EMOJI=" 🚧"                                # Emoji prefix
declare -g __DEBUG_TAG=" [DEBUG] -"                           # Tag prefix
declare -g __DEBUG_INDENT=1                                   # Number of leading spaces (default: 1)

# ==================================================================================================
# PUBLIC FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Print debug message (dynamically generated at init)
# Usage: debug <message>
# Note: This function is a placeholder, overwritten by debug_init()
debug() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Enable debug output (with optional silent mode)
# Usage: debug_enable [silent]
debug_enable() {
    declare -g "$__DEBUG_VAR_NAME=1"
    __debug_init_state
    [[ "${1:-}" != "silent" ]] && debug "Debug enabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Disable debug output (with optional silent mode)
# Usage: debug_disable [silent]
debug_disable() {
    [[ "${1:-}" != "silent" ]] && debug "Debug disabled"
    declare -g "$__DEBUG_VAR_NAME=0"
    __debug_init_state
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Toggle debug state
# Usage: debug_toggle
debug_toggle() {
    if [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]; then
        debug_disable
    else
        debug_enable
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Consolidated setter for all debug options
# Usage: debug_set <option> <value>
# Options: state, output, timestamp, datestamp, emoji, tag, indent
# Example: debug_set timestamp 0; debug_set emoji " 🔧"; debug_set indent 5
debug_set() {
    local option="$1" value="$2"

    case "$option" in
        state)
            case "$value" in
                true|1|on|enabled) debug_enable ;;
                false|0|off|disabled) debug_disable ;;
                *) echo "Error: Invalid state '$value'" >&2; return 1 ;;
            esac
            ;;
        output|file)
            if [[ -n "$value" ]]; then
                local dir
                dir="$(dirname "$value")"
                [[ ! -d "$dir" ]] && mkdir -p "$dir" 2>/dev/null
                if ! touch "$value" 2>/dev/null; then
                    echo "Error: Cannot write to: $value" >&2
                    return 1
                fi
            fi
            __DEBUG_OUTPUT_FILE="$value"
            __debug_init_functions
            ;;
        timestamp)
            case "$value" in
                1|true|on|enabled) __DEBUG_USE_TIMESTAMP=1 ;;
                0|false|off|disabled) __DEBUG_USE_TIMESTAMP=0 ;;
                *) echo "Error: Invalid value '$value'" >&2; return 1 ;;
            esac
            __debug_init_functions
            ;;
        datestamp)
            case "$value" in
                1|true|on|enabled) __DEBUG_USE_DATESTAMP=1 ;;
                0|false|off|disabled) __DEBUG_USE_DATESTAMP=0 ;;
                *) echo "Error: Invalid value '$value'" >&2; return 1 ;;
            esac
            __debug_init_functions
            ;;
        emoji)
            __DEBUG_EMOJI="$value"
            __debug_init_functions
            ;;
        tag)
            __DEBUG_TAG="$value"
            __debug_init_functions
            ;;
        indent)
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                echo "Error: Invalid indent '$value'" >&2
                return 1
            fi
            __DEBUG_INDENT="$value"
            __debug_init_functions
            ;;
        *)
            echo "Error: Unknown option '$option'" >&2
            echo "Usage: debug_set <option> <value>" >&2
            echo "Options: state, output, timestamp, datestamp, emoji, tag, indent" >&2
            return 1
            ;;
    esac
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current debug variable name
# Usage: var_name=$(debug_get_var_name)
debug_get_var_name() { echo "$__DEBUG_VAR_NAME"; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current debug state (dynamically generated)
# Usage: state=$(debug_get_state)
# Returns: "enabled" or "disabled"
# Note: Rewritten by __debug_init_state()
debug_get_state() { echo "disabled"; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Check if debug is enabled (dynamically generated)
# Usage: debug_is_enabled && echo "Debug is on"
# Returns: 0 if enabled, 1 if disabled
# Note: Rewritten by __debug_init_state()
debug_is_enabled() { return 1; }
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# INTERNAL FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Internal: Initialize state-dependent functions (debug_is_enabled, debug_get_state)
# Usage: __debug_init_state
# Note: Called by debug_enable/debug_disable
__debug_init_state() {
    if [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]; then
        # Enabled: no checks needed
        source /dev/stdin <<<'debug_is_enabled() { return 0; }'
        source /dev/stdin <<<'debug_get_state() { echo "enabled"; }'
    else
        # Disabled: always return failure
        source /dev/stdin <<<'debug_is_enabled() { return 1; }'
        source /dev/stdin <<<'debug_get_state() { echo "disabled"; }'
    fi
    __debug_init_functions
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Internal: Initialize debug function based on current format settings
# Usage: __debug_init_functions
# Note: Called by __debug_init_state and debug_set
__debug_init_functions() {
    local var_name indent_str ts_fmt fmt_str

    var_name="$__DEBUG_VAR_NAME"

    # Build indent
    printf -v indent_str '%*s' "$__DEBUG_INDENT" ''

    # Build timestamp format
    if [[ $__DEBUG_USE_TIMESTAMP -eq 1 ]]; then
        if [[ $__DEBUG_USE_DATESTAMP -eq 1 ]]; then
            printf -v ts_fmt '%s' '%(%Y-%m-%d %H:%M:%S)T'
        else
            printf -v ts_fmt '%s' '%(%H:%M:%S)T'
        fi
    else
        ts_fmt=''
    fi

    # Build complete format string
    printf -v fmt_str '%s%s%%s%%s %%s\n' "$indent_str" "$ts_fmt"

    # Generate state-based debug function
    if [[ "${!var_name}" -eq 1 ]]; then
        # Enabled: build output and send to destinations
        if [[ -n "$__DEBUG_OUTPUT_FILE" ]]; then
            if [[ -n "$ts_fmt" ]]; then
                source /dev/stdin <<<'debug() { local o; printf -v o "'"$fmt_str"'" "-1" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"; echo "$o" >&2; echo "$o" >> "'"$__DEBUG_OUTPUT_FILE"'"; }'
            else
                source /dev/stdin <<<'debug() { local o; printf -v o "'"$fmt_str"'" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"; echo "$o" >&2; echo "$o" >> "'"$__DEBUG_OUTPUT_FILE"'"; }'
            fi
        else
            if [[ -n "$ts_fmt" ]]; then
                source /dev/stdin <<<'debug() { local o; printf -v o "'"$fmt_str"'" "-1" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"; echo "$o" >&2; }'
            else
                source /dev/stdin <<<'debug() { local o; printf -v o "'"$fmt_str"'" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"; echo "$o" >&2; }'
            fi
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
__debug_init_state

# ==================================================================================================
# BACKWARD COMPATIBILITY - Legacy setter functions (wrappers around debug_set)
# ==================================================================================================

debug_set_output_file() { debug_set output "$1"; }
debug_set_timestamp() { debug_set timestamp "$1"; }
debug_set_datestamp() { debug_set datestamp "$1"; }
debug_set_emoji() { debug_set emoji "$1"; }
debug_set_tag() { debug_set tag "$1"; }
debug_set_indent() { debug_set indent "$1"; }
