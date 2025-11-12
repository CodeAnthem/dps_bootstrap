#!/usr/bin/env bash
# ==================================================================================================
# Logger - Standalone Feature
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-12
# Description:   Timestamped logging with multiple levels and optional file output
# Feature:       info/warn/error/fatal/success, console output, file logging
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
# GLOBAL VARIABLES - Configuration
# ==================================================================================================

declare -g __LOG_OUTPUT_FILE=""                               # Optional file path for log output
declare -g __LOG_TO_STDERR=1                                  # 1=log to stderr, 0=stdout
declare -g __LOG_USE_TIMESTAMP=1                              # Show timestamp (1=yes, 0=no)
declare -g __LOG_USE_DATESTAMP=1                              # Show date in timestamp (1=yes, 0=no)
declare -g __LOG_INDENT=1                                     # Number of leading spaces (default: 1)

# Default emojis and tags per level
declare -g __LOG_INFO_EMOJI=" ℹ️ "
declare -g __LOG_INFO_TAG=" [INFO] -"
declare -g __LOG_WARN_EMOJI=" ⚠️ "
declare -g __LOG_WARN_TAG=" [WARN] -"
declare -g __LOG_ERROR_EMOJI=" ❌"
declare -g __LOG_ERROR_TAG=" [ERROR] -"
declare -g __LOG_FATAL_EMOJI=" ❌"
declare -g __LOG_FATAL_TAG=" [FATAL] -"
declare -g __LOG_SUCCESS_EMOJI=" ✅"
declare -g __LOG_SUCCESS_TAG=" [SUCCESS] -"
declare -g __LOG_VALIDATION_EMOJI=" ❌"
declare -g __LOG_VALIDATION_TAG=" [VALIDATION] -"

# ==================================================================================================
# PUBLIC FUNCTIONS - Logging (dynamically generated)
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Info message (dynamically generated at init)
# Usage: info <message>
info() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Warning message (dynamically generated at init)
# Usage: warn <message>
warn() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Error message (dynamically generated at init)
# Usage: error <message>
error() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Fatal error message (dynamically generated at init)
# Usage: fatal <message>
fatal() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Success message (dynamically generated at init)
# Usage: success <message>
success() { :; }
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Validation error message (dynamically generated at init)
# Usage: validation_error <message>
validation_error() { :; }
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# PUBLIC FUNCTIONS - Console helpers (not dynamically generated)
# ==================================================================================================

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
# PUBLIC FUNCTIONS - Configuration
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Initialize/reinitialize all logging functions based on current settings
# Usage: log_init
# Note: Called automatically on source, call again after changing settings
log_init() {
    local indent_str ts_fmt stream_redir console_printf file_printf

    # Build indent string
    printf -v indent_str '%*s' "$__LOG_INDENT" ''

    # Build timestamp format
    if [[ $__LOG_USE_TIMESTAMP -eq 1 ]]; then
        if [[ $__LOG_USE_DATESTAMP -eq 1 ]]; then
            ts_fmt='%(%Y-%m-%d %H:%M:%S)T'
        else
            ts_fmt='%(%H:%M:%S)T'
        fi
    else
        ts_fmt=''
    fi

    # Determine output redirection
    if [[ $__LOG_TO_STDERR -eq 1 ]]; then
        stream_redir='>&2'
    else
        stream_redir=''
    fi

    # Generate each logging function
    local levels=(
        "info:$__LOG_INFO_EMOJI:$__LOG_INFO_TAG"
        "warn:$__LOG_WARN_EMOJI:$__LOG_WARN_TAG"
        "error:$__LOG_ERROR_EMOJI:$__LOG_ERROR_TAG"
        "fatal:$__LOG_FATAL_EMOJI:$__LOG_FATAL_TAG"
        "success:$__LOG_SUCCESS_EMOJI:$__LOG_SUCCESS_TAG"
        "validation_error:$__LOG_VALIDATION_EMOJI:$__LOG_VALIDATION_TAG"
    )

    for level_spec in "${levels[@]}"; do
        IFS=: read -r func_name emoji tag <<< "$level_spec"

        # Build printf statements
        if [[ -n "$ts_fmt" ]]; then
            console_printf='printf "'"$indent_str"'"'"$ts_fmt"'%s%s %s\\n" "-1" "'"$emoji"'" "'"$tag"'" "$1" '"$stream_redir"
            file_printf='printf "'"$indent_str"'"'"$ts_fmt"'%s%s %s\\n" "-1" "'"$emoji"'" "'"$tag"'" "$1" >> "'"$__LOG_OUTPUT_FILE"'"'
        else
            console_printf='printf "'"$indent_str"'%s%s %s\\n" "'"$emoji"'" "'"$tag"'" "$1" '"$stream_redir"
            file_printf='printf "'"$indent_str"'%s%s %s\\n" "'"$emoji"'" "'"$tag"'" "$1" >> "'"$__LOG_OUTPUT_FILE"'"'
        fi

        # Generate optimized one-liner function
        if [[ -n "$__LOG_OUTPUT_FILE" ]]; then
            source /dev/stdin <<<"${func_name}() { $console_printf; $file_printf; }"
        else
            source /dev/stdin <<<"${func_name}() { $console_printf; }"
        fi
    done
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set log output file
# Usage: log_set_output_file <filepath>
# Note: Set to empty string to disable file output. Calls log_init() automatically.
log_set_output_file() {
    local file_path="$1"

    if [[ -n "$file_path" ]]; then
        # Create directory if it doesn't exist
        local dir
        dir="$(dirname "$file_path")"
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || {
                printf "[ERROR] Cannot create directory for log output: %s\n" "$dir" >&2
                return 1
            }
        fi

        # Test if file is writable
        if ! touch "$file_path" 2>/dev/null; then
            printf "[ERROR] Cannot write to log output file: %s\n" "$file_path" >&2
            return 1
        fi

        __LOG_OUTPUT_FILE="$file_path"
        log_init
        info "Log output file set: $file_path"
    else
        __LOG_OUTPUT_FILE=""
        log_init
        info "Log output file disabled"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get current log output file
# Usage: file=$(log_get_output_file)
log_get_output_file() {
    echo "$__LOG_OUTPUT_FILE"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set timestamp display
# Usage: log_set_timestamp <1|0>
# Note: Calls log_init() automatically
log_set_timestamp() {
    local state="$1"
    case "$state" in
        1|true|on|enabled) __LOG_USE_TIMESTAMP=1 ;;
        0|false|off|disabled) __LOG_USE_TIMESTAMP=0 ;;
        *) echo "Error: Invalid state '$state' (use: 1/0/true/false)" >&2; return 1 ;;
    esac
    log_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set datestamp display (date portion of timestamp)
# Usage: log_set_datestamp <1|0>
# Note: Calls log_init() automatically
log_set_datestamp() {
    local state="$1"
    case "$state" in
        1|true|on|enabled) __LOG_USE_DATESTAMP=1 ;;
        0|false|off|disabled) __LOG_USE_DATESTAMP=0 ;;
        *) echo "Error: Invalid state '$state' (use: 1/0/true/false)" >&2; return 1 ;;
    esac
    log_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set output stream (stderr or stdout)
# Usage: log_set_stream <stderr|stdout>
# Note: Calls log_init() automatically
log_set_stream() {
    local stream="$1"
    case "$stream" in
        stderr|2) __LOG_TO_STDERR=1 ;;
        stdout|1) __LOG_TO_STDERR=0 ;;
        *) echo "Error: Invalid stream '$stream' (use: stderr/stdout)" >&2; return 1 ;;
    esac
    log_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set emoji for a specific log level
# Usage: log_set_emoji <level> <emoji>
# Level: info, warn, error, fatal, success, validation
# Note: Calls log_init() automatically
log_set_emoji() {
    local level="$1" emoji="$2"
    case "$level" in
        info) __LOG_INFO_EMOJI="$emoji" ;;
        warn) __LOG_WARN_EMOJI="$emoji" ;;
        error) __LOG_ERROR_EMOJI="$emoji" ;;
        fatal) __LOG_FATAL_EMOJI="$emoji" ;;
        success) __LOG_SUCCESS_EMOJI="$emoji" ;;
        validation) __LOG_VALIDATION_EMOJI="$emoji" ;;
        *) echo "Error: Invalid level '$level'" >&2; return 1 ;;
    esac
    log_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set indent (number of leading spaces)
# Usage: log_set_indent <number>
# Note: Calls log_init() automatically
log_set_indent() {
    local indent="$1"
    if [[ ! "$indent" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid indent '$indent' (must be a number)" >&2
        return 1
    fi
    __LOG_INDENT="$indent"
    log_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set tag for a specific log level
# Usage: log_set_tag <level> <tag>
# Level: info, warn, error, fatal, success, validation
# Note: Calls log_init() automatically
log_set_tag() {
    local level="$1" tag="$2"
    case "$level" in
        info) __LOG_INFO_TAG="$tag" ;;
        warn) __LOG_WARN_TAG="$tag" ;;
        error) __LOG_ERROR_TAG="$tag" ;;
        fatal) __LOG_FATAL_TAG="$tag" ;;
        success) __LOG_SUCCESS_TAG="$tag" ;;
        validation) __LOG_VALIDATION_TAG="$tag" ;;
        *) echo "Error: Invalid level '$level'" >&2; return 1 ;;
    esac
    log_init
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Clear log file
# Usage: log_clear_file
log_clear_file() {
    if [[ -z "$__LOG_OUTPUT_FILE" ]]; then
        echo "Warning: No log output file configured" >&2
        return 1
    fi

    if [[ -f "$__LOG_OUTPUT_FILE" ]]; then
        : > "$__LOG_OUTPUT_FILE"
        # Don't use info() here - it would write to the file we just cleared
        echo " ℹ️  [INFO] - Log file cleared: $__LOG_OUTPUT_FILE" >&2
    else
        echo "Warning: Log file does not exist: $__LOG_OUTPUT_FILE" >&2
    fi
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# AUTO-INITIALIZATION
# ==================================================================================================

# Initialize all logging functions based on current settings
log_init
