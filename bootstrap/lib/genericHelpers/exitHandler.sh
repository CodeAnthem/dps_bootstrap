#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Trap setup and exit/cleanup management
# Feature:       Central exit handler, interrupt handler and crash helper that calls hooks
# ==================================================================================================

declare -g NDS_FATAL_MESSAGE="" # Fatal message placeholder (set by nds_crash)
declare -g NDS_EXIT_REGISTER="" # Function name to call on exit
declare -ga NDS_CLEANUP_REGISTER=() # Array of functions to call on exit

# Public: initialize traps (call once from main)
# Usage: nds_trap_init
nds_trap_init() {
    trap _nds_trap_onInterrupt SIGINT
    trap _nds_trap_onExit EXIT
}

# Public: Trigger a controlled fatal that sets a message and exits with code 200
# Usage: crash "message"
crash() {
    NDS_FATAL_MESSAGE="$1"
    exit 200
}

# Public: Register a function to be called on exit
# Usage: nds_trap_registerExit "functionName"
nds_trap_registerExit() {
    local registerFunc="$1"
    if declare -f "$registerFunc" &>/dev/null; then
        NDS_EXIT_REGISTER="$registerFunc"
        return 0
    fi
    error "Function '$registerFunc' not found"
    return 1
}

# Public: Register a function to be called on exit
# Usage: nds_trap_registerCleanup "functionName"
nds_trap_registerCleanup() {
    local registerFunc="$1"
    if declare -f "$registerFunc" &>/dev/null; then
        NDS_CLEANUP_REGISTER+=("$registerFunc")
        return 0
    fi
    error "Function '$registerFunc' not found"
    return 1
}

# Private: internal exit handler called by the EXIT trap
# It will call an optional hook "exit_msg" (hook may output a message),
# display a default message otherwise, purge runtime dir and call "exit_cleanup" hook.
_nds_trap_onExit() {
    local exitCode=$?
    local exitMsg=""

    if [[ -n "${NDS_EXIT_REGISTER:-}" ]]; then
        exitMsg="$($NDS_EXIT_REGISTER "$exitCode")"
    fi

    if [[ -n "$exitMsg" ]]; then
        console "$exitMsg"
    else
        case "$exitCode" in
            0)
                success "Script completed successfully"
                ;;
            130)
                warn "Script aborted by user"
                ;;
            200)
                fatal "Internal error! - ${NDS_FATAL_MESSAGE:-}"
                ;;
            *)
                warn "Script failed with exit code: $exitCode"
                ;;
        esac
    fi

    # Call registered cleanup functions
    for func in "${NDS_CLEANUP_REGISTER[@]}"; do
        if declare -f "$func" &>/dev/null; then
            "$func" "$exitCode"
        fi
    done
}

# Private: interrupt handler for SIGINT
_nds_trap_onInterrupt() {
    echo || true # print new_line to keep UI tidy if user pressed ^C during a prompt
    exit 130
}


