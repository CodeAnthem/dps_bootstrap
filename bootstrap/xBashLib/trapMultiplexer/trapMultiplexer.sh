#!/usr/bin/env bash
# ==================================================================================================
# Trap Multiplexer - Standalone Feature
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-09 | Modified: 2025-11-28
# Description:   Advanced signal handler stacking with priorities, limits, and exit policies
# Feature:       Named handlers, priority execution, one-shot/N-shot, exit policies
# ==================================================================================================
# shellcheck disable=SC2329 # This function is never invoked

# ==================================================================================================
# VALIDATION & INITIALIZATION
# ==================================================================================================

# Prevent execution - this file must be sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed" >&2
    echo "Usage: source ${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Check for required Bash features (associative arrays require Bash 4.0+)
if ! declare -A __test_assoc_array 2>/dev/null; then
    echo "Error: Trap Multiplexer requires Bash with associative array support (Bash 4.0+)" >&2
    exit 1
fi
unset __test_assoc_array

# Output interface functions - define if not already present
if ! declare -F debug &>/dev/null; then
    debug() { :; }
fi
if ! declare -F info &>/dev/null; then
    info() { printf "[INFO] %s\n" "$*" >&2; }
fi
if ! declare -F warn &>/dev/null; then
    warn() { printf "[WARN] %s\n" "$*" >&2; }
fi
if ! declare -F error &>/dev/null; then
    error() { printf "[ERROR] %s\n" "$*" >&2; }
fi
if ! declare -F fatal &>/dev/null; then
    fatal() { printf "[FATAL] %s\n" "$*" >&2; return 1; }
fi

# ==================================================================================================
# GLOBAL VARIABLES
# ==================================================================================================

declare -g __TRAP_RDEL=$'\x1F'                                # Internal delimiter for handler key lists
declare -g __TRAP_NAME_SEQ=0                                  # Counter for anonymous handler names
declare -gA __TRAP_REGISTRY=()                                # Maps signal -> "sig:name1<RDEL>sig:name2..."
declare -gA __TRAP_HANDLER_CODE=()                            # Maps handler key -> code/function
declare -gA __TRAP_HANDLER_PRIORITY=()                        # Maps handler key -> priority (default 0)
declare -gA __TRAP_HANDLER_LIMIT=()                           # Maps handler key -> exec limit (0=unlimited)
declare -gA __TRAP_HANDLER_COUNT=()                           # Maps handler key -> execution count
declare -gA __TRAP_INITIALIZED=()                             # Maps signal -> 1 if dispatcher installed
declare -gA __TRAP_EXIT_POLICY=()                             # Maps signal -> exit policy (always|once|never|force)
declare -gA __TRAP_SUSPENDED=()                               # Maps signal -> 1 if suspended, 0 if active
declare -g __TRAP_IN_EXIT=0                                   # Flag: currently in EXIT trap (prevent recursion)
declare -g __TRAP_EVAL_DISABLED=0                             # Flag: eval disabled (for debugging/safety)
declare -g __TRAP_EXIT_CODE=0                                 # Exit code captured at trap dispatch time
declare -g TRAP_LAST_NAME=""                                  # Public: Last registered handler name (with signal prefix)

# Default exit policy for SIGINT - force exit after handlers complete
__TRAP_EXIT_POLICY["SIGINT"]="force"

# ==================================================================================================
# PUBLIC FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Override builtin trap to support handler stacking
# Usage: trap <code> <signal>...
# Note: Creates anonymous handler. Use trap_named for named handlers with priority control.
trap() {
    # Delegate special options to builtin
    # shellcheck disable=SC2064
    case "${1:-}" in
        -p|-l|'') builtin trap "$@"; return;;
    esac
    
    local code="$1"; shift
    local sig
    
    # Loop allows: trap 'code' EXIT TERM INT (registers for multiple signals)
    for sig in "$@"; do
        __trap_register_handler -s "$sig" -c "$code"
    done
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Register named handler with optional priority
# Usage: trap_named <name> <code> <signal>... [--priority NUM]
trap_named() {
    local name="$1" code="$2"
    shift 2
    
    if [[ -z "$name" || -z "$code" ]]; then
        error "Usage: trap_named <name> <code> <signal>... [--priority NUM]"
        return 1
    fi
    
    # Parse signals and optional priority
    local -a signals=()
    local priority=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --priority)
                priority="${2:-}"
                shift 2
                ;;
            *)
                signals+=("$1")
                shift
                ;;
        esac
    done
    
    if [[ ${#signals[@]} -eq 0 ]]; then
        error "At least one signal required"
        return 1
    fi
    
    # Loop allows: trap_named "name" "code" EXIT TERM INT --priority 10
    local sig
    for sig in "${signals[@]}"; do
        if [[ -n "$priority" ]]; then
            __trap_register_handler -s "$sig" -n "$name" -c "$code" -p "$priority"
        else
            __trap_register_handler -s "$sig" -n "$name" -c "$code"
        fi
    done
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set exit behavior policy for signal
# Usage: trap_policy_exit_set <signal> <policy>
# Policy: once (default) | never | always | force
trap_policy_exit_set() {
    local sig="$1" policy="$2"
    
    if [[ -z "$sig" ]]; then
        error "Usage: trap_policy_exit_set <signal> <policy>"
        return 1
    fi
    
    case "$policy" in
        once|never|always|force)
            __TRAP_EXIT_POLICY[$sig]="$policy"
            debug "Set exit policy for $sig: $policy"
            ;;
        *)
            error "Invalid policy '$policy' (use: once, never, always, force)"
            return 1
            ;;
    esac
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get exit behavior policy for signal
# Usage: trap_policy_exit_get <signal>
# Returns: Policy string (once|never|always|force)
trap_policy_exit_get() {
    local sig="$1"
    echo "${__TRAP_EXIT_POLICY[$sig]:-once}"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set handler priority
# Usage: trap_policy_priority_set <signal:name> <priority>
# Priority: Higher value = execute first (default: 0)
trap_policy_priority_set() {
    local handler_key="$1" priority="$2"
    
    if [[ -z "$handler_key" || -z "$priority" ]]; then
        error "Usage: trap_policy_priority_set <signal:name> <priority>"
        return 1
    fi
    
    if [[ ! "$priority" =~ ^-?[0-9]+$ ]]; then
        error "Priority must be an integer"
        return 1
    fi
    
    __TRAP_HANDLER_PRIORITY[$handler_key]="$priority"
    debug "Set priority for $handler_key: $priority"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get handler priority
# Usage: trap_policy_priority_get <signal:name>
# Returns: Priority value
trap_policy_priority_get() {
    local handler_key="$1"
    echo "${__TRAP_HANDLER_PRIORITY[$handler_key]:-0}"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Set handler execution limit
# Usage: trap_policy_limit_set <signal:name> <limit>
# Limit: 0=unlimited, 1=one-shot, N=N-shot
trap_policy_limit_set() {
    local handler_key="$1" limit="$2"
    
    if [[ -z "$handler_key" || -z "$limit" ]]; then
        error "Usage: trap_policy_limit_set <signal:name> <limit>"
        return 1
    fi
    
    if [[ ! "$limit" =~ ^[0-9]+$ ]]; then
        error "Limit must be a non-negative integer"
        return 1
    fi
    
    __TRAP_HANDLER_LIMIT[$handler_key]="$limit"
    debug "Set limit for $handler_key: $limit"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get handler execution limit
# Usage: trap_policy_limit_get <signal:name>
# Returns: Limit value
trap_policy_limit_get() {
    local handler_key="$1"
    echo "${__TRAP_HANDLER_LIMIT[$handler_key]:-0}"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get handler information
# Usage: trap_handler_info <signal:name>
# Returns: code, priority, limit, count (one per line)
trap_handler_info() {
    local handler_key="$1"
    
    if [[ -z "$handler_key" ]]; then
        error "Usage: trap_handler_info <signal:name>"
        return 1
    fi
    
    if [[ -z "${__TRAP_HANDLER_CODE[$handler_key]:-}" ]]; then
        error "Handler not found: $handler_key"
        return 1
    fi
    
    echo "code=${__TRAP_HANDLER_CODE[$handler_key]}"
    echo "priority=${__TRAP_HANDLER_PRIORITY[$handler_key]:-0}"
    echo "limit=${__TRAP_HANDLER_LIMIT[$handler_key]:-0}"
    echo "count=${__TRAP_HANDLER_COUNT[$handler_key]:-0}"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: List all handler names for a signal
# Usage: trap_list <signal>
# Returns: Newline-separated handler names (not full keys)
trap_list() {
    local sig="$1"
    
    if [[ -z "$sig" ]]; then
        error "Usage: trap_list <signal>"
        return 1
    fi
    
    local keys
    keys="$(__trap_get_handler_keys "$sig")"
    [[ -z "$keys" ]] && return 0
    
    # Extract names from "sig:name" format using parameter expansion
    local key name
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        name="${key#*:}"
        echo "$name"
    done <<< "$keys"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Check if signal has any handlers
# Usage: trap_has <signal>
# Returns: 0 if handlers exist, 1 if none
trap_has() {
    local sig="$1"
    [[ -n "${__TRAP_REGISTRY[$sig]:-}" ]]
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Get count of handlers for a signal
# Usage: trap_count <signal>
# Returns: Number of registered handlers
trap_count() {
    local sig="$1"
    
    if [[ -z "$sig" ]]; then
        error "Usage: trap_count <signal>"
        return 1
    fi
    
    local keys
    keys="$(__trap_get_handler_keys "$sig")"
    [[ -z "$keys" ]] && { echo 0; return 0; }
    
    echo "$keys" | wc -l
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Remove specific handler by name
# Usage: trap_unregister <signal> <name>
trap_unregister() {
    local sig="$1" name="$2"
    
    if [[ -z "$sig" || -z "$name" ]]; then
        error "Usage: trap_unregister <signal> <name>"
        return 1
    fi
    
    local handler_key="${sig}:${name}"
    __trap_remove_handler_key "$sig" "$handler_key"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Clear all handlers for a signal
# Usage: trap_clear <signal>
trap_clear() {
    local sig="$1"
    
    if [[ -z "$sig" ]]; then
        error "Usage: trap_clear <signal>"
        return 1
    fi
    
    # Get all handler keys and remove them
    local keys
    keys="$(__trap_get_handler_keys "$sig")"
    
    if [[ -n "$keys" ]]; then
        local key
        while IFS= read -r key; do
            __trap_remove_handler_key "$sig" "$key"
        done <<< "$keys"
    fi
    
    # Final cleanup
    builtin trap - "$sig"
    unset "__TRAP_REGISTRY[$sig]" "__TRAP_INITIALIZED[$sig]" "__TRAP_EXIT_POLICY[$sig]" "__TRAP_SUSPENDED[$sig]"
    debug "Cleared all handlers for $sig"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Suspend handlers for a signal (temporarily disable)
# Usage: trap_suspend <signal>
trap_suspend() {
    local sig="$1"
    
    if [[ -z "$sig" ]]; then
        error "Usage: trap_suspend <signal>"
        return 1
    fi
    
    __TRAP_SUSPENDED[$sig]=1
    debug "Suspended handlers for $sig"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Resume handlers for a signal (re-enable after suspend)
# Usage: trap_resume <signal>
trap_resume() {
    local sig="$1"
    
    if [[ -z "$sig" ]]; then
        error "Usage: trap_resume <signal>"
        return 1
    fi
    
    __TRAP_SUSPENDED[$sig]=0
    debug "Resumed handlers for $sig"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Check if signal handlers are suspended
# Usage: trap_is_suspended <signal>
# Returns: 0 if suspended, 1 if active
trap_is_suspended() {
    local sig="$1"
    [[ "${__TRAP_SUSPENDED[$sig]:-0}" == "1" ]]
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Disable eval for security - only function names allowed after this call
# Usage: trap_disable_eval
# Note: This is irreversible (uses readonly). Only functions will execute, inline code will be ignored.
trap_disable_eval() {
    if [[ $__TRAP_EVAL_DISABLED -eq 0 ]]; then
        __TRAP_EVAL_DISABLED=1
        readonly __TRAP_EVAL_DISABLED
        warn "Eval disabled - only function-based trap handlers will execute"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Debug utility - show all registered signals and their handlers
# Usage: trap_debug
trap_debug() {
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         TRAP MULTIPLEXER DEBUG                                 ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Collect all unique signals
    local -a signals=()
    local sig
    for sig in "${!__TRAP_REGISTRY[@]}"; do
        [[ -n "$sig" ]] && signals+=("$sig")
    done
    
    if [[ ${#signals[@]} -eq 0 ]]; then
        echo "No trap handlers registered."
        return 0
    fi
    
    # Sort signals
    mapfile -t signals < <(printf '%s\n' "${signals[@]}" | sort)
    
    for sig in "${signals[@]}"; do
        [[ -z "$sig" ]] && continue
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Signal: $sig"
        echo "  Policy:    ${__TRAP_EXIT_POLICY[$sig]:-once}"
        echo "  Suspended: ${__TRAP_SUSPENDED[$sig]:-0}"
        echo "  Handlers:"
        
        local keys
        keys="$(__trap_get_sorted_handlers "$sig")"
        
        if [[ -z "$keys" ]]; then
            echo "    (none)"
        else
            local key name priority limit count code
            while IFS= read -r key; do
                [[ -z "$key" ]] && continue
                name="${key#*:}"
                priority="${__TRAP_HANDLER_PRIORITY[$key]:-0}"
                limit="${__TRAP_HANDLER_LIMIT[$key]:-0}"
                count="${__TRAP_HANDLER_COUNT[$key]:-0}"
                code="${__TRAP_HANDLER_CODE[$key]:-}"
                
                # Truncate code if too long
                if [[ ${#code} -gt 50 ]]; then
                    code="${code:0:47}..."
                fi
                
                echo "    - $name"
                echo "        Priority: $priority | Limit: $limit | Count: $count"
                echo "        Code: $code"
            done <<< "$keys"
        fi
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local eval_status="false"
    [[ $__TRAP_EVAL_DISABLED -eq 1 ]] && eval_status="true"
    echo "Eval disabled: $eval_status"
    echo "Last registered: $TRAP_LAST_NAME"
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# PRIVATE FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Private: Get handler keys for signal as array
# Usage: __trap_get_handler_keys <signal>
# Returns: Newline-separated handler keys
__trap_get_handler_keys() {
    local sig="$1"
    local list="${__TRAP_REGISTRY[$sig]:-}"
    [[ -z "$list" ]] && return 0
    printf '%s\n' "${list//$__TRAP_RDEL/$'\n'}"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Private: Get sorted handler keys by priority (descending)
# Usage: __trap_get_sorted_handlers <signal>
# Returns: Newline-separated handler keys sorted by priority
__trap_get_sorted_handlers() {
    local sig="$1"
    local keys
    local -a handler_list
    
    # Get all handler keys
    keys="$(__trap_get_handler_keys "$sig")"
    [[ -z "$keys" ]] && return 0
    
    # Read into array
    mapfile -t handler_list <<< "$keys"
    
    # Sort by priority (higher first), maintain order for same priority
    # Format for sort: "priority handler_key"
    local -a sorted_pairs=()
    local key priority
    
    for key in "${handler_list[@]}"; do
        priority="${__TRAP_HANDLER_PRIORITY[$key]:-0}"
        sorted_pairs+=("$priority $key")
    done
    
    # Sort numerically by first field (descending), stable sort
    printf '%s\n' "${sorted_pairs[@]}" | sort -rn -s -k1,1 | cut -d' ' -f2-
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Private: Execute a single handler
# Usage: __trap_execute_handler <handler_key> <signal>
# Returns: 0 if executed, 1 if skipped (limit reached), 2 if should be removed
__trap_execute_handler() {
    local handler_key="$1" sig="$2"
    local code limit count
    
    code="${__TRAP_HANDLER_CODE[$handler_key]:-}"
    [[ -z "$code" ]] && return 1
    
    # Check execution limit
    limit="${__TRAP_HANDLER_LIMIT[$handler_key]:-0}"
    count="${__TRAP_HANDLER_COUNT[$handler_key]:-0}"
    
    if [[ $limit -gt 0 && $count -ge $limit ]]; then
        debug "Handler $handler_key limit reached ($count/$limit), marking for removal"
        return 2  # Signal removal even if not executed
    fi
    
    debug "Executing handler: $handler_key (priority: ${__TRAP_HANDLER_PRIORITY[$handler_key]:-0}, count: $count/$limit)"
    
    # Execute handler - check if it's a bare function name or inline code
    # Only treat as function if: valid identifier, function exists, and not 'exit'
    if [[ "$code" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && declare -F "$code" &>/dev/null && [[ "$code" != "exit" ]]; then
        # Function call
        "$code" "$sig"
    else
        # Inline code - check if eval is disabled
        if [[ $__TRAP_EVAL_DISABLED -eq 1 ]]; then
            warn "Skipping inline handler (eval disabled): $handler_key"
            return 1
        fi
        eval "$code"
    fi
    
    # Increment execution count
    __TRAP_HANDLER_COUNT[$handler_key]=$((count + 1))
    
    # Auto-remove if limit reached
    if [[ $limit -gt 0 && $((count + 1)) -ge $limit ]]; then
        debug "Handler $handler_key reached limit, will be removed"
        return 2  # Special return code signals "remove me"
    fi
    
    return 0
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Private: Register handler with metadata (argument-based)
# Usage: __trap_register_handler -s <signal> -c <code> [-n <name>] [-p <priority>]
# Required: -s (signal), -c (code)
# Optional: -n (name, auto-generated if empty), -p (priority, default 0)
__trap_register_handler() {
    local sig="" name="" code="" priority="0"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s) sig="$2"; shift 2;;
            -n) name="$2"; shift 2;;
            -c) code="$2"; shift 2;;
            -p) priority="$2"; shift 2;;
            *) error "Unknown argument: $1"; return 1;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$sig" ]]; then
        error "Signal (-s) is required"
        return 1
    fi
    if [[ -z "$code" ]]; then
        error "Code (-c) is required"
        return 1
    fi
    
    # Generate anonymous name if not provided
    if [[ -z "$name" ]]; then
        __TRAP_NAME_SEQ=$((__TRAP_NAME_SEQ + 1))
        printf -v name 'anonymous_%(%s)T_%d' -1 "$__TRAP_NAME_SEQ"
    fi
    
    local handler_key="${sig}:${name}"
    
    # Store handler code
    __TRAP_HANDLER_CODE[$handler_key]="$code"
    
    # Use existing validation functions for priority
    if [[ -n "$priority" ]]; then
        trap_policy_priority_set "$handler_key" "$priority" || return 1
    fi
    
    # Initialize limit and count
    __TRAP_HANDLER_LIMIT[$handler_key]="${__TRAP_HANDLER_LIMIT[$handler_key]:-0}"
    __TRAP_HANDLER_COUNT[$handler_key]=0
    
    # Append to registry
    if [[ -n "${__TRAP_REGISTRY[$sig]:-}" ]]; then
        __TRAP_REGISTRY[$sig]+="$__TRAP_RDEL$handler_key"
    else
        __TRAP_REGISTRY[$sig]="$handler_key"
    fi
    
    # Install dispatcher - ALWAYS install to ensure it's set
    # This ensures both trap() and trap_named() properly install the dispatcher
    if [[ -z "${__TRAP_INITIALIZED[$sig]:-}" ]]; then
        # shellcheck disable=SC2064
        builtin trap "__trap_dispatch '$sig'" "$sig"
        __TRAP_INITIALIZED[$sig]=1
        debug "Installed dispatcher for $sig"
    fi
    
    # Update public last name variable
    TRAP_LAST_NAME="$handler_key"
    
    debug "Registered handler: $handler_key (priority: $priority)"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Private: Main dispatcher - executes all handlers for a signal
# Usage: __trap_dispatch <signal>
__trap_dispatch() {
    # CRITICAL: Capture $? FIRST before any other commands
    __TRAP_EXIT_CODE=$?
    
    local sig="$1"
    
    debug "Trap dispatcher called for signal: $sig (exit_code=$__TRAP_EXIT_CODE)"
    
    # Check if suspended
    if [[ "${__TRAP_SUSPENDED[$sig]:-0}" == "1" ]]; then
        debug "Signal $sig is suspended, ignoring"
        return 0
    fi
    
    # Cleanup if no handlers
    if [[ -z "${__TRAP_REGISTRY[$sig]:-}" ]]; then
        debug "No handlers for $sig, cleaning up"
        builtin trap - "$sig"
        unset "__TRAP_INITIALIZED[$sig]"
        return 0
    fi
    
    # Special handling for EXIT (prevent recursion)
    if [[ "$sig" == "EXIT" ]]; then
        (( __TRAP_IN_EXIT )) && return 0
        __TRAP_IN_EXIT=1
        debug "Executing EXIT handlers"
        
        local handler_key
        local -a handlers_to_remove=()
        
        # Get sorted handlers
        while IFS= read -r handler_key; do
            [[ -z "$handler_key" ]] && continue
            __trap_execute_handler "$handler_key" "$sig"
            local ret=$?
            [[ $ret -eq 2 ]] && handlers_to_remove+=("$handler_key")
        done < <(__trap_get_sorted_handlers "$sig")
        
        # Remove handlers that reached limit
        for handler_key in "${handlers_to_remove[@]}"; do
            __trap_remove_handler_key "$sig" "$handler_key"
        done
        
        __TRAP_IN_EXIT=0
        return 0
    fi
    
    # Non-EXIT signals with exit policy
    local policy="${__TRAP_EXIT_POLICY[$sig]:-once}"
    local handler_key
    local -a handlers_to_remove=()
    
    debug "Executing $sig handlers with exit policy: $policy"
    
    # Policy 'always': Don't override exit, let native behavior happen
    if [[ "$policy" == "always" ]]; then
        while IFS= read -r handler_key; do
            [[ -z "$handler_key" ]] && continue
            __trap_execute_handler "$handler_key" "$sig"
            local ret=$?
            [[ $ret -eq 2 ]] && handlers_to_remove+=("$handler_key")
        done < <(__trap_get_sorted_handlers "$sig")
        
        # Remove limited handlers
        for handler_key in "${handlers_to_remove[@]}"; do
            __trap_remove_handler_key "$sig" "$handler_key"
        done
        
        return 0
    fi
    
    # Policy 'once', 'never', or 'force': Override exit to capture codes
    # Reset capture globals
    __TRAP_FIRST_EXIT=""
    __TRAP_LAST_EXIT=""
    __TRAP_EXIT_CALLED=0
    
    # Hijack exit function to capture exit codes
    exit() {
        local code="${1:-0}"
        # Capture first exit code
        if [[ $__TRAP_EXIT_CALLED -eq 0 ]]; then
            __TRAP_FIRST_EXIT="$code"
        fi
        # Always update last exit code
        __TRAP_LAST_EXIT="$code"
        __TRAP_EXIT_CALLED=1
        # Don't actually exit, just capture
        return 0
    }
    
    # Prevent signal re-entry during handlers
    builtin trap '' "$sig"
    
    # Execute all handlers (sorted by priority)
    while IFS= read -r handler_key; do
        [[ -z "$handler_key" ]] && continue
        __trap_execute_handler "$handler_key" "$sig"
        local ret=$?
        [[ $ret -eq 2 ]] && handlers_to_remove+=("$handler_key")
    done < <(__trap_get_sorted_handlers "$sig")
    
    # Reinstall dispatcher
    # shellcheck disable=SC2064
    builtin trap "__trap_dispatch '$sig'" "$sig"
    
    # Remove our exit override
    unset -f exit
    
    # Remove handlers that reached limit
    for handler_key in "${handlers_to_remove[@]}"; do
        __trap_remove_handler_key "$sig" "$handler_key"
    done
    
    # Act based on policy AFTER all handlers ran
    case "$policy" in
        force)
            # Exit with first exit code (or 0 if no exit called)
            if [[ $__TRAP_EXIT_CALLED -eq 1 ]]; then
                debug "Policy 'force': Exiting with first code $__TRAP_FIRST_EXIT"
                trap '' EXIT  # Prevent re-entrancy
                builtin exit "$__TRAP_FIRST_EXIT"
            else
                debug "Policy 'force': No exit called, exiting with 0"
                trap '' EXIT  # Prevent re-entrancy
                builtin exit 0
            fi
            ;;
        once)
            # Exit with last exit code (only if exit was called)
            if [[ $__TRAP_EXIT_CALLED -eq 1 ]]; then
                debug "Policy 'once': Exiting with last code $__TRAP_LAST_EXIT"
                trap '' EXIT  # Prevent re-entrancy
                builtin exit "$__TRAP_LAST_EXIT"
            fi
            # If no exit() was called, don't exit
            ;;
        never)
            # Ignore all exit requests, continue execution
            debug "Policy 'never': Ignoring exit requests (first=${__TRAP_FIRST_EXIT:-none}, last=${__TRAP_LAST_EXIT:-none})"
            ;;
    esac
    
    # Reset capture globals for next use
    __TRAP_FIRST_EXIT=""
    __TRAP_LAST_EXIT=""
    __TRAP_EXIT_CALLED=0
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Private: Remove handler key from signal registry
# Usage: __trap_remove_handler_key <signal> <handler_key>
__trap_remove_handler_key() {
    local sig="$1" handler_key="$2"
    local old="${__TRAP_REGISTRY[$sig]:-}"
    [[ -z "$old" ]] && return 0
    
    local new="" key
    local -a parts
    IFS="$__TRAP_RDEL" read -ra parts <<< "$old"
    
    for key in "${parts[@]}"; do
        [[ "$key" != "$handler_key" ]] && new+="${new:+$__TRAP_RDEL}$key"
    done
    
    if [[ -n "$new" ]]; then
        __TRAP_REGISTRY[$sig]="$new"
    else
        # No handlers left, cleanup
        unset "__TRAP_REGISTRY[$sig]"
        builtin trap - "$sig"
        unset "__TRAP_INITIALIZED[$sig]"
    fi
    
    # Clean up handler metadata
    unset "__TRAP_HANDLER_CODE[$handler_key]"
    unset "__TRAP_HANDLER_PRIORITY[$handler_key]"
    unset "__TRAP_HANDLER_LIMIT[$handler_key]"
    unset "__TRAP_HANDLER_COUNT[$handler_key]"
    
    # Clear TRAP_LAST_NAME if it references this handler
    if [[ "$TRAP_LAST_NAME" == "$handler_key" ]]; then
        TRAP_LAST_NAME=""
    fi
    
    debug "Removed handler: $handler_key"
}
# --------------------------------------------------------------------------------------------------
