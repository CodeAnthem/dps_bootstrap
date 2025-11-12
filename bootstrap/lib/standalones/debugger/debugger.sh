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

# ==================================================================================================
# PUBLIC FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Print debug message (dynamically generated at init)
# Usage: debug <message>
# Note: This function is a placeholder, overwritten by debug_init()
debug() {
    : # Will be replaced by debug_init()
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Enable debug output
# Usage: debug_enable
debug_enable() {
    declare -g "$__DEBUG_VAR_NAME=1"
    debug "Debug enabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Disable debug output
# Usage: debug_disable
debug_disable() {
    debug "Debug disabled"
    declare -g "$__DEBUG_VAR_NAME=0"
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
# Public: Check if debug is enabled
# Usage: debug_is_enabled && echo "Debug is on"
# Returns: 0 if enabled, 1 if disabled
debug_is_enabled() {
    [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set debug state explicitly
# Usage: debug_set true|false|1|0
debug_set() {
    local state="$1"

    case "$state" in
        true|1|on|enabled)
            debug_enable
            ;;
        false|0|off|disabled)
            debug_disable
            ;;
        *)
            echo "Error: Invalid debug state '$state' (use: true/false/1/0/on/off)" >&2
            return 1
            ;;
    esac
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set output file for debug messages
# Usage: debug_set_output_file <filepath>
# Note: Set to empty string to disable file output. Calls debug_init() automatically.
debug_set_output_file() {
    local file_path="$1"

    if [[ -n "$file_path" ]]; then
        # Create directory if it doesn't exist
        local dir
        dir="$(dirname "$file_path")"
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || {
                echo "Error: Cannot create directory for debug output: $dir" >&2
                return 1
            }
        fi

        # Test if file is writable
        if ! touch "$file_path" 2>/dev/null; then
            echo "Error: Cannot write to debug output file: $file_path" >&2
            return 1
        fi

        __DEBUG_OUTPUT_FILE="$file_path"
        debug_init
        debug "Debug output file set: $file_path"
    else
        __DEBUG_OUTPUT_FILE=""
        debug_init
        debug "Debug output file disabled"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set timestamp display
# Usage: debug_set_timestamp <1|0>
# Note: Calls debug_init() automatically
debug_set_timestamp() {
    local state="$1"
    case "$state" in
        1|true|on|enabled) __DEBUG_USE_TIMESTAMP=1 ;;
        0|false|off|disabled) __DEBUG_USE_TIMESTAMP=0 ;;
        *) echo "Error: Invalid state '$state' (use: 1/0/true/false)" >&2; return 1 ;;
    esac
    debug_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set datestamp display (date portion of timestamp)
# Usage: debug_set_datestamp <1|0>
# Note: Calls debug_init() automatically
debug_set_datestamp() {
    local state="$1"
    case "$state" in
        1|true|on|enabled) __DEBUG_USE_DATESTAMP=1 ;;
        0|false|off|disabled) __DEBUG_USE_DATESTAMP=0 ;;
        *) echo "Error: Invalid state '$state' (use: 1/0/true/false)" >&2; return 1 ;;
    esac
    debug_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set emoji prefix
# Usage: debug_set_emoji <emoji_string>
# Note: Calls debug_init() automatically
debug_set_emoji() {
    __DEBUG_EMOJI="$1"
    debug_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set tag prefix
# Usage: debug_set_tag <tag_string>
# Note: Calls debug_init() automatically
debug_set_tag() {
    __DEBUG_TAG="$1"
    debug_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current debug variable name
# Usage: var_name=$(debug_get_var_name)
debug_get_var_name() {
    echo "$__DEBUG_VAR_NAME"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current debug state as string
# Usage: state=$(debug_get_state)
# Returns: "enabled" or "disabled"
debug_get_state() {
    if [[ "${!__DEBUG_VAR_NAME}" -eq 1 ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Initialize/reinitialize debug function based on current settings
# Usage: debug_init
# Note: Called automatically on source, call again after changing settings
debug_init() {
    local func_body var_ref ts_code file_code output_line

    # Direct variable reference (no indirection for performance)
    var_ref="\${$__DEBUG_VAR_NAME}"

    # Build timestamp code
    # shellcheck disable=SC2016
    if [[ $__DEBUG_USE_TIMESTAMP -eq 1 ]]; then
        if [[ $__DEBUG_USE_DATESTAMP -eq 1 ]]; then
            ts_code='local ts; printf -v ts "%(%Y-%m-%d %H:%M:%S)T" -1 2>/dev/null'
            output_line='printf " %s%s%s %s\\n" "$ts" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"'
        else
            ts_code='local ts; printf -v ts "%(%H:%M:%S)T" -1 2>/dev/null'
            output_line='printf " %s%s%s %s\\n" "$ts" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"'
        fi
    else
        ts_code=''
        output_line='printf "%s%s %s\\n" "'"$__DEBUG_EMOJI"'" "'"$__DEBUG_TAG"'" "$1"'
    fi

    # Build file output code
    if [[ -n "$__DEBUG_OUTPUT_FILE" ]]; then
        file_code="$output_line >> \"$__DEBUG_OUTPUT_FILE\""
    else
        file_code=''
    fi

    # Generate optimized function
    func_body="debug() {"
    func_body+=$'\n'"    [[ $var_ref -eq 0 ]] && return 0"
    if [[ -n "$ts_code" ]]; then
        func_body+=$'\n'"    $ts_code"
    fi
    func_body+=$'\n'"    $output_line >&2"
    if [[ -n "$file_code" ]]; then
        func_body+=$'\n'"    $file_code"
    fi
    func_body+=$'\n'"}"

    # Source the function definition (no eval needed)
    # shellcheck disable=SC1091
    source /dev/stdin <<<"$func_body"
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# AUTO-INITIALIZATION
# ==================================================================================================

# Initialize debug function based on current settings
debug_init

# If the debug variable is set to "true" or "false" string, convert to 1/0
if [[ "${!__DEBUG_VAR_NAME}" == "true" ]]; then
    debug_enable
elif [[ "${!__DEBUG_VAR_NAME}" == "false" ]]; then
    debug_disable
fi
