#!/usr/bin/env bash
# ==================================================================================================
# Streams - Standalone Feature
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-13 | Modified: 2025-11-25
# Description:   Unified channel-based output system with dynamic function generation
# Feature:       Multi-channel routing (stdout, stderr, logger, debug), file output, NOP control
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

# Bash version check - require 4.2+ for associative arrays and printf %(...)T
if [[ -z "${BASH_VERSINFO[0]}" ]] || [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || \
   [[ "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 2 ]]; then
    echo "Error: Bash 4.2 or higher required (you have ${BASH_VERSION:-unknown})" >&2
    echo "Required features: associative arrays, printf %(...)T timestamp format" >&2
    return 1 2>/dev/null || exit 1
fi


# ==================================================================================================
# GLOBAL VARIABLES - Configuration
# ==================================================================================================

# Channels array
declare -gra __STREAMS_CHANNELS=("stdout" "stderr" "logger" "debug")

# Single configuration array with key patterns
declare -gA __STREAMS_CONFIG=(
    # Channel settings: console output, file output, file path
    [CHANNEL::stdout::CONSOLE]=1
    [CHANNEL::stdout::FILE]=0
    [CHANNEL::stdout::FILE_PATH]=""
    [CHANNEL::stdout::FD]=1
    [CHANNEL::stderr::CONSOLE]=1
    [CHANNEL::stderr::FILE]=0
    [CHANNEL::stderr::FILE_PATH]=""
    [CHANNEL::stderr::FD]=2
    [CHANNEL::logger::CONSOLE]=1
    [CHANNEL::logger::FILE]=1
    [CHANNEL::logger::FILE_PATH]=""
    [CHANNEL::logger::FD]=3
    [CHANNEL::debug::CONSOLE]=1
    [CHANNEL::debug::FILE]=1
    [CHANNEL::debug::FILE_PATH]=""
    [CHANNEL::debug::FD]=4
    
    # Format settings
    [FORMAT::CONSOLE::DATE]=1
    [FORMAT::CONSOLE::TIME]=1
    [FORMAT::CONSOLE::INDENT]=1
    [FORMAT::FILE::DATE]=1
    [FORMAT::FILE::TIME]=1
    [FORMAT::SUPPRESS_EMOJIS]=0
    
    # Predefined function registry
    [FUNC::log::EMOJI]=""
    [FUNC::log::TAG]=""
    [FUNC::log::CHANNEL]="stdout"
    [FUNC::log::EXIT]="-1"
    [FUNC::log::NOP]="0"
    
    [FUNC::info::EMOJI]=" ℹ️ "
    [FUNC::info::TAG]=" [INFO] -"
    [FUNC::info::CHANNEL]="logger"
    [FUNC::info::EXIT]="-1"
    [FUNC::info::NOP]="0"
    
    [FUNC::warn::EMOJI]=" ⚠️ "
    [FUNC::warn::TAG]=" [WARN] -"
    [FUNC::warn::CHANNEL]="logger"
    [FUNC::warn::EXIT]="-1"
    [FUNC::warn::NOP]="0"
    
    [FUNC::error::EMOJI]=" ❌"
    [FUNC::error::TAG]=" [ERROR] -"
    [FUNC::error::CHANNEL]="stderr"
    [FUNC::error::EXIT]="-1"
    [FUNC::error::NOP]="0"
    
    [FUNC::fatal::EMOJI]=" 💀"
    [FUNC::fatal::TAG]=" [FATAL] -"
    [FUNC::fatal::CHANNEL]="stderr"
    [FUNC::fatal::EXIT]="1"
    [FUNC::fatal::NOP]="0"
    
    [FUNC::pass::EMOJI]=" ✅"
    [FUNC::pass::TAG]=" [PASS] -"
    [FUNC::pass::CHANNEL]="logger"
    [FUNC::pass::EXIT]="-1"
    [FUNC::pass::NOP]="0"
    
    [FUNC::fail::EMOJI]=" ❌"
    [FUNC::fail::TAG]=" [FAIL] -"
    [FUNC::fail::CHANNEL]="stderr"
    [FUNC::fail::EXIT]="-1"
    [FUNC::fail::NOP]="0"
    
    [FUNC::debug::EMOJI]=" 🐛"
    [FUNC::debug::TAG]=" [DEBUG] -"
    [FUNC::debug::CHANNEL]="debug"
    [FUNC::debug::EXIT]="-1"
    [FUNC::debug::NOP]="1"
)

# Registry to track all defined functions (for iteration)
declare -ga __STREAMS_FUNCTIONS=("log" "info" "warn" "error" "fatal" "pass" "fail" "debug")

# FD registry - tracks which FDs (3-9) have been opened by streams
# Empty array = no FDs opened yet. Array elements are FD numbers that have been opened.
declare -ga __STREAMS_OPENED_FDS=()


# ==================================================================================================
# PUBLIC FUNCTIONS - Channel Configuration
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Configure channel settings
# Usage: stream_set_channel [channel] --console BOOL --file BOOL --file-path PATH
# Note: If no channel specified, applies to all channels
stream_set_channel() {
    local channel=""
    local needs_reinit=0
    
    # Check if first arg is a channel name
    if [[ " ${__STREAMS_CHANNELS[*]} " == *" ${1:-} "* ]]; then
        channel="$1"
        shift
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --console)
                case "${2:-}" in
                    1|true|on|enabled) 
                        if [[ -n "$channel" ]]; then
                            __STREAMS_CONFIG[CHANNEL::${channel}::CONSOLE]=1
                        else
                            for ch in "${__STREAMS_CHANNELS[@]}"; do
                                __STREAMS_CONFIG[CHANNEL::${ch}::CONSOLE]=1
                            done
                        fi
                        needs_reinit=1
                        ;;
                    0|false|off|disabled)
                        # Safety check: prevent disabling console for stdout
                        if [[ "$channel" == "stdout" ]]; then
                            echo "Error: Cannot disable console output for stdout channel" >&2
                            return 1
                        fi
                        if [[ -n "$channel" ]]; then
                            __STREAMS_CONFIG[CHANNEL::${channel}::CONSOLE]=0
                        else
                            for ch in "${__STREAMS_CHANNELS[@]}"; do
                                [[ "$ch" == "stdout" ]] && continue
                                __STREAMS_CONFIG[CHANNEL::${ch}::CONSOLE]=0
                            done
                        fi
                        needs_reinit=1
                        ;;
                    *)
                        echo "Error: Invalid --console value '${2:-}' (use: 1/0, true/false, on/off)" >&2
                        return 1
                        ;;
                esac
                shift 2
                ;;
            --file)
                case "${2:-}" in
                    1|true|on|enabled)
                        if [[ -n "$channel" ]]; then
                            __STREAMS_CONFIG[CHANNEL::${channel}::FILE]=1
                        else
                            for ch in "${__STREAMS_CHANNELS[@]}"; do
                                __STREAMS_CONFIG[CHANNEL::${ch}::FILE]=1
                            done
                        fi
                        needs_reinit=1
                        ;;
                    0|false|off|disabled)
                        if [[ -n "$channel" ]]; then
                            __STREAMS_CONFIG[CHANNEL::${channel}::FILE]=0
                        else
                            for ch in "${__STREAMS_CHANNELS[@]}"; do
                                __STREAMS_CONFIG[CHANNEL::${ch}::FILE]=0
                            done
                        fi
                        needs_reinit=1
                        ;;
                    *)
                        echo "Error: Invalid --file value '${2:-}' (use: 1/0, true/false, on/off)" >&2
                        return 1
                        ;;
                esac
                shift 2
                ;;
            --file-path)
                [[ $# -lt 2 ]] && { echo "Error: --file-path requires a value" >&2; return 1; }
                local file_path="$2"
                if [[ -n "$file_path" ]]; then
                    # Validate path - directory must exist or be creatable
                    local dir
                    dir="$(dirname "$file_path")" || { echo "Error: Invalid file path '$file_path'" >&2; return 1; }
                    if [[ ! -d "$dir" ]]; then
                        mkdir -p "$dir" 2>/dev/null || {
                            echo "Error: Cannot create directory: $dir" >&2
                            return 1
                        }
                    fi
                fi
                if [[ -n "$channel" ]]; then
                    __STREAMS_CONFIG[CHANNEL::${channel}::FILE_PATH]="$file_path"
                else
                    for ch in "${__STREAMS_CHANNELS[@]}"; do
                        __STREAMS_CONFIG[CHANNEL::${ch}::FILE_PATH]="$file_path"
                    done
                fi
                needs_reinit=1
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Usage: stream_set_channel [channel] --console BOOL --file BOOL --file-path PATH" >&2
                return 1
                ;;
        esac
    done
    
    # Only reinitialize once after all changes
    [[ $needs_reinit -eq 1 ]] && __streams_defineFN_all
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Configure format settings
# Usage: stream_set_format [console|file] --date BOOL --time BOOL --indent NUM --tab NUM
# Note: If no format specified, applies to both console and file
stream_set_format() {
    local format=""
    local needs_reinit=0
    
    # Check if first arg is format type
    if [[ "${1:-}" == "console" ]] || [[ "${1:-}" == "file" ]]; then
        format="$1"
        shift
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --date)
                case "${2:-}" in
                    1|true|on|enabled)
                        if [[ -n "$format" ]]; then
                            __STREAMS_CONFIG[FORMAT::${format^^}::DATE]=1
                        else
                            __STREAMS_CONFIG[FORMAT::CONSOLE::DATE]=1
                            __STREAMS_CONFIG[FORMAT::FILE::DATE]=1
                        fi
                        needs_reinit=1
                        ;;
                    0|false|off|disabled)
                        if [[ -n "$format" ]]; then
                            __STREAMS_CONFIG[FORMAT::${format^^}::DATE]=0
                        else
                            __STREAMS_CONFIG[FORMAT::CONSOLE::DATE]=0
                            __STREAMS_CONFIG[FORMAT::FILE::DATE]=0
                        fi
                        needs_reinit=1
                        ;;
                    *)
                        echo "Error: Invalid --date value '${2:-}'" >&2
                        return 1
                        ;;
                esac
                shift 2
                ;;
            --time)
                case "${2:-}" in
                    1|true|on|enabled)
                        if [[ -n "$format" ]]; then
                            __STREAMS_CONFIG[FORMAT::${format^^}::TIME]=1
                        else
                            __STREAMS_CONFIG[FORMAT::CONSOLE::TIME]=1
                            __STREAMS_CONFIG[FORMAT::FILE::TIME]=1
                        fi
                        needs_reinit=1
                        ;;
                    0|false|off|disabled)
                        if [[ -n "$format" ]]; then
                            __STREAMS_CONFIG[FORMAT::${format^^}::TIME]=0
                        else
                            __STREAMS_CONFIG[FORMAT::CONSOLE::TIME]=0
                            __STREAMS_CONFIG[FORMAT::FILE::TIME]=0
                        fi
                        needs_reinit=1
                        ;;
                    *)
                        echo "Error: Invalid --time value '${2:-}'" >&2
                        return 1
                        ;;
                esac
                shift 2
                ;;
            --indent)
                [[ -z "${2:-}" ]] && { echo "Error: --indent requires a value" >&2; return 1; }
                if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                    echo "Error: Invalid --indent value '$2' (must be a number >= 0)" >&2
                    return 1
                fi
                case "${1}" in
                    console|file)
                        __STREAMS_CONFIG[FORMAT::${1^^}::INDENT]="$2"
                        ;;
                    *)
                        __STREAMS_CONFIG[FORMAT::CONSOLE::INDENT]="$2"
                        ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            --suppress-emojis)
                case "${2:-}" in
                    1|true|on|enabled) __STREAMS_CONFIG[FORMAT::SUPPRESS_EMOJIS]=1 ;;
                    0|false|off|disabled) __STREAMS_CONFIG[FORMAT::SUPPRESS_EMOJIS]=0 ;;
                    *)
                        echo "Error: Invalid --suppress-emojis value '${2:-}'" >&2
                        return 1
                        ;;
                esac
                needs_reinit=1
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Usage: stream_set_format [console|file] --date BOOL --time BOOL --indent NUM --tab NUM --suppress-emojis BOOL" >&2
                return 1
                ;;
        esac
    done
    
    # Only reinitialize once after all changes
    [[ $needs_reinit -eq 1 ]] && __streams_defineFN_all
}
# --------------------------------------------------------------------------------------------------


# ==================================================================================================
# PUBLIC FUNCTIONS - Function Management
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Create or modify a stream function
# Usage: stream_function <name> [--emoji EMOJI] [--tag TAG] [--channel CHANNEL] [--exit CODE] [--enable|--disable]
stream_function() {
    local name="${1:-}"
    [[ -z "$name" ]] && { echo "Error: Function name required" >&2; return 1; }
    shift
    
    local needs_reinit=0
    local is_new=0
    
    # Check if function exists
    if [[ ! " ${__STREAMS_FUNCTIONS[*]} " == *" $name "* ]]; then
        # New function - add to registry
        __STREAMS_FUNCTIONS+=("$name")
        is_new=1
    fi
    
    # Set defaults for new functions
    if [[ $is_new -eq 1 ]]; then
        __STREAMS_CONFIG[FUNC::${name}::EMOJI]=""
        __STREAMS_CONFIG[FUNC::${name}::TAG]=" [${name^^}] -"
        __STREAMS_CONFIG[FUNC::${name}::CHANNEL]="logger"
        __STREAMS_CONFIG[FUNC::${name}::EXIT]="-1"
        __STREAMS_CONFIG[FUNC::${name}::NOP]="0"
    fi
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --emoji)
                __STREAMS_CONFIG[FUNC::${name}::EMOJI]="${2:-}"
                needs_reinit=1
                shift 2
                ;;
            --tag)
                __STREAMS_CONFIG[FUNC::${name}::TAG]="${2:-}"
                needs_reinit=1
                shift 2
                ;;
            --channel)
                if [[ ! " ${__STREAMS_CHANNELS[*]} " == *" ${2:-} "* ]]; then
                    echo "Error: Invalid channel '${2:-}' (must be one of: ${__STREAMS_CHANNELS[*]})" >&2
                    return 1
                fi
                __STREAMS_CONFIG[FUNC::${name}::CHANNEL]="${2:-}"
                needs_reinit=1
                shift 2
                ;;
            --exit)
                if [[ ! "${2:-}" =~ ^-?[0-9]+$ ]]; then
                    echo "Error: --exit must be a number" >&2
                    return 1
                fi
                __STREAMS_CONFIG[FUNC::${name}::EXIT]="${2:-}"
                needs_reinit=1
                shift 2
                ;;
            --enable)
                __STREAMS_CONFIG[FUNC::${name}::NOP]="0"
                needs_reinit=1
                shift
                ;;
            --disable)
                __STREAMS_CONFIG[FUNC::${name}::NOP]="1"
                needs_reinit=1
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                return 1
                ;;
        esac
    done
    
    # Regenerate this function
    [[ $needs_reinit -eq 1 ]] && __streams_defineFN_single "$name"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Close all opened file descriptors (except 1 and 2)
# Usage: stream_cleanup
# Note: Call this to clean up FDs opened by streams (typically at script exit)
# IMPORTANT: Do NOT call debug/info/etc here - we're closing those FDs!
stream_cleanup() {
    local fd
    
    # Close all FDs tracked in registry
    for fd in "${__STREAMS_OPENED_FDS[@]}"; do
        # Safety check: only close FDs 3-9
        if [[ "$fd" -ge 3 && "$fd" -le 9 ]]; then
            eval "exec ${fd}>&-" 2>/dev/null || :
        fi
    done
    
    # Clear registry
    __STREAMS_OPENED_FDS=()
}
# --------------------------------------------------------------------------------------------------


# ==================================================================================================
# INTERNAL FUNCTIONS - FD Management
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Internal: Validate and ensure FD is open
# Usage: __streams_ensure_fd <fd_number>
# Returns: 0 on success, 1 on error
__streams_ensure_fd() {
    local fd="$1"
    
    # Validate FD is a number
    if ! [[ "$fd" =~ ^[0-9]+$ ]]; then
        echo "Error: FD must be a number, got: $fd" >&2
        return 1
    fi
    
    # FD 1-2 are always available (stdout, stderr)
    if [[ "$fd" -eq 1 || "$fd" -eq 2 ]]; then
        return 0
    fi
    
    # FD 3-9 are allowed and managed
    if [[ "$fd" -ge 3 && "$fd" -le 9 ]]; then
        # Check if already opened
        for opened_fd in "${__STREAMS_OPENED_FDS[@]}"; do
            if [[ "$opened_fd" -eq "$fd" ]]; then
                return 0  # Already open
            fi
        done
        
        # Open FD as duplicate of stderr
        eval "exec ${fd}>&2"
        
        # Track in registry
        __STREAMS_OPENED_FDS+=("$fd")
        return 0
    fi
    
    # FD outside 1-9 range is an error
    echo "Error: FD must be in range 1-9, got: $fd" >&2
    return 1
}
# --------------------------------------------------------------------------------------------------


# ==================================================================================================
# INTERNAL FUNCTIONS - Function Generation
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Internal: Define all stream functions
# Usage: __streams_defineFN_all
__streams_defineFN_all() {
    # Generate special output() function first
    __streams_defineFN_output
    
    # Generate regular functions
    for func_name in "${__STREAMS_FUNCTIONS[@]}"; do
        __streams_defineFN_single "$func_name"
    done
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Internal: Define output() function - mimics echo with optional file logging
# Usage: __streams_defineFN_output
# Note: output() always writes to stdout (fd1) with NO formatting
#       If stdout channel has file output enabled, writes to file WITH formatting
__streams_defineFN_output() {
    # Unset existing function
    unset -f "output" 2>/dev/null || :
    
    # Get stdout channel file settings
    local file_out="${__STREAMS_CONFIG[CHANNEL::stdout::FILE]}"
    local file_path="${__STREAMS_CONFIG[CHANNEL::stdout::FILE_PATH]}"
    
    # Build file format (empty emoji/tag for output, but keep timestamp if enabled)
    __streams_build_format "file" "" ""
    local file_fmt="$__STREAMS_FMT_RESULT"
    local ts_arg="$__STREAMS_TS_ARG"
    
    # Escape single quotes in format string
    file_fmt="${file_fmt//\'/\'\\\'\'}"
    
    # Escape file path
    local safe_file_path
    safe_file_path=$(printf '%q' "$file_path")
    
    # Build function
    # Console: plain echo (true echo behavior)
    # File: formatted output (with timestamp if enabled)
    local file_cmd=""
    [[ "$file_out" == "1" && -n "$file_path" ]] && file_cmd="printf -- '${file_fmt} %s\\n' ${ts_arg}\"\${*:-\\\"\\\"}\" >> ${safe_file_path};"
    
    if [[ -n "$file_cmd" ]]; then
        # With file output
        eval "output() { echo \"\$@\"; ${file_cmd} }"
    else
        # Console only
        eval "output() { echo \"\$@\"; }"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Internal: Define single stream function (hardened with safe escaping)
# Usage: __streams_defineFN_single <function_name>
__streams_defineFN_single() {
    local func_name="$1"
    
    # Unset existing function to ensure clean replacement
    unset -f "$func_name" 2>/dev/null || :
    
    # Get function attributes
    local emoji="${__STREAMS_CONFIG[FUNC::${func_name}::EMOJI]}"
    local tag="${__STREAMS_CONFIG[FUNC::${func_name}::TAG]}"
    local channel="${__STREAMS_CONFIG[FUNC::${func_name}::CHANNEL]}"
    local exit_code="${__STREAMS_CONFIG[FUNC::${func_name}::EXIT]}"
    local is_nop="${__STREAMS_CONFIG[FUNC::${func_name}::NOP]}"
    
    # If NOP, generate no-op function
    if [[ "$is_nop" == "1" ]]; then
        eval "${func_name}() { :; }"
        return 0
    fi
    
    # Get channel attributes
    local console_out="${__STREAMS_CONFIG[CHANNEL::${channel}::CONSOLE]}"
    local file_out="${__STREAMS_CONFIG[CHANNEL::${channel}::FILE]}"
    local file_path="${__STREAMS_CONFIG[CHANNEL::${channel}::FILE_PATH]}"
    local channel_fd="${__STREAMS_CONFIG[CHANNEL::${channel}::FD]}"
    
    # Ensure FD is valid and open (if needed)
    if ! __streams_ensure_fd "$channel_fd"; then
        echo "Error: Failed to ensure FD $channel_fd for function $func_name (channel: $channel)" >&2
        return 1
    fi
    
    # Apply emoji suppression
    [[ "${__STREAMS_CONFIG[FORMAT::SUPPRESS_EMOJIS]}" == "1" ]] && emoji=""
    
    # Build exit statement
    local ifExit=""
    [[ "$exit_code" == "-1" ]] || ifExit="exit $exit_code;"
    
    # Build console format string (% already escaped in emoji/tag)
    __streams_build_format "console" "$emoji" "$tag"
    local console_fmt="$__STREAMS_FMT_RESULT"
    local ts_arg="$__STREAMS_TS_ARG"
    
    # Build file format string
    __streams_build_format "file" "$emoji" "$tag"
    local file_fmt="$__STREAMS_FMT_RESULT"
    
    # Escape single quotes in format strings for safe embedding in single-quoted eval
    # (% already escaped, now handle ' by replacing with '\'' for shell safety)
    console_fmt="${console_fmt//\'/\'\\\'\'}"
    file_fmt="${file_fmt//\'/\'\\\'\'}"
    
    # Escape file path using printf %q (handles spaces, quotes, etc.)
    local safe_file_path
    safe_file_path=$(printf '%q' "$file_path")
    
    # Build console and file output statements with FD error protection
    # Note: Single backslash before $ for runtime evaluation in generated function
    # Note: Using $* to capture all arguments (allows: info this is unquoted)
    local console_cmd=""
    if [[ "$console_out" == "1" ]]; then
        # Wrap console output with FD check and error handling
        console_cmd="if ! printf -- '${console_fmt} %s\\n' ${ts_arg}\"\${*:-\\\"<No message> - \${FUNCNAME[1]}()#\${BASH_LINENO[0]} in \${BASH_SOURCE[1]}\\\"}\" >&${channel_fd} 2>/dev/null; then printf '[STREAM ERROR] %s called after stream_cleanup. Message: %s\\n' '${func_name}' \"\${*:-<no message>}\" >&2; fi;"
    fi
    
    local file_cmd=""
    [[ "$file_out" == "1" && -n "$file_path" ]] && file_cmd="printf -- '${file_fmt} %s\\n' ${ts_arg}\"\${*:-\\\"<No message> - \${FUNCNAME[1]}()#\${BASH_LINENO[0]} in \${BASH_SOURCE[1]}\\\"}\" >> ${safe_file_path} 2>/dev/null;"
    
    # Generate function (single path, no branches)
    if [[ -n "$console_cmd" || -n "$file_cmd" ]]; then
        eval "${func_name}() { $console_cmd $file_cmd $ifExit }"
    else
        # No output (NOP)
        eval "${func_name}() { :; }"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Internal: Build format string for console or file (with % escaping for user content)
# Usage: __streams_build_format <console|file> <emoji> <tag>
# Result: Sets __STREAMS_FMT_RESULT and __STREAMS_TS_ARG
__streams_build_format() {
    local format_type="${1^^}"  # CONSOLE or FILE
    local emoji="$2"
    local tag="$3"
    
    # Apply emoji suppression
    if [[ "${__STREAMS_CONFIG[FORMAT::SUPPRESS_EMOJIS]}" == "1" ]]; then
        emoji=""
    fi
    
    # Escape % in user-supplied content to prevent format string injection
    # (% needs to be %% in printf format strings, except for %(...)T)
    emoji="${emoji//%/%%}"
    tag="${tag//%/%%}"
    
    # Get format settings
    local use_date="${__STREAMS_CONFIG[FORMAT::${format_type}::DATE]}"
    local use_time="${__STREAMS_CONFIG[FORMAT::${format_type}::TIME]}"
    local indent="${__STREAMS_CONFIG[FORMAT::${format_type}::INDENT]:-0}"
    
    # Build format string
    local fmt_parts=""
    __STREAMS_TS_ARG=""
    
    # Add indent (console only)
    if [[ "$format_type" == "CONSOLE" && "$indent" -gt 0 ]]; then
        printf -v fmt_parts '%*s' "$indent" ''
    fi
    
    # Add timestamp (%(...)T tokens are safe, not user-supplied)
    if [[ "$use_date" == "1" && "$use_time" == "1" ]]; then
        fmt_parts="${fmt_parts}%(%Y-%m-%d %H:%M:%S)T"
        __STREAMS_TS_ARG="-1 "
    elif [[ "$use_time" == "1" ]]; then
        fmt_parts="${fmt_parts}%(%H:%M:%S)T"
        __STREAMS_TS_ARG="-1 "
    fi
    
    # Add emoji and tag (already escaped)
    fmt_parts="${fmt_parts}${emoji}${tag}"
    
    __STREAMS_FMT_RESULT="$fmt_parts"
}
# --------------------------------------------------------------------------------------------------


# ==================================================================================================
# AUTO-INITIALIZATION
# ==================================================================================================

# Auto-initialization happens on source for immediate usability based on current settings.
# If you modify settings after sourcing, call __streams_defineFN_all manually to regenerate functions.
__streams_defineFN_all


