#!/usr/bin/env bash
# ==================================================================================================
# NDS - Runtime directory and install logging
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-07
# Description:   Central runtime dir and persistent install log
# ==================================================================================================

readonly NDS_INSTALL_LOG="/tmp/nds_session.log"
# Verbose nix install output (nixos-install, partitioning, step exec). Per-session
# path is set in nds_runtime_init; this default is only used before init.
NDS_INSTALL_DETAIL_LOG="/tmp/nds_install.log"

# Setup runtime directory for config/secrets scratch space.
# Usage: nds_runtime_init
nds_runtime_init() {
    local timestamp=""
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    [[ -n "$timestamp" ]] || return 1

    RUNTIME_DIR="/tmp/nds_${timestamp}_$$"
    mkdir -p "$RUNTIME_DIR/config" "$RUNTIME_DIR/secrets" || return 1
    chmod 700 "$RUNTIME_DIR" || return 1

    export RUNTIME_DIR
    export NDS_RUNTIME_DIR="$RUNTIME_DIR"
    export NDS_INSTALL_DETAIL_LOG="${RUNTIME_DIR}/install.log"
    export NDS_INSTALL_DIAG_LOG="${RUNTIME_DIR}/diag.log"
    : >"$NDS_INSTALL_DETAIL_LOG"
    : >"$NDS_INSTALL_DIAG_LOG"
    return 0
}

# Remove runtime directory on exit.
# Usage: nds_runtime_purge
nds_runtime_purge() {
    if [[ -d "${RUNTIME_DIR:-}" ]]; then
        if rm -rf "$RUNTIME_DIR"; then
            success " > Removed runtime directory: $RUNTIME_DIR"
        else
            error " > Failed to remove runtime directory: $RUNTIME_DIR"
        fi
    fi
}

# Description: Append a line to the session log (events, warnings, info).
# The verbose nix install output goes to NDS_INSTALL_DETAIL_LOG instead.
# Usage: nds_install_log "message"
nds_install_log() {
    local message="$1"
    local stamp
    printf -v stamp '%(%Y-%m-%d %H:%M:%S)T' -1
    printf '%s %s\n' "$stamp" "$message" >> "$NDS_INSTALL_LOG"
}
