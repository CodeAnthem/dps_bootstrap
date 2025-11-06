#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-11-06
# Description:   General output and logging helpers + debug management
# Feature:       Timestamped logs (no subshell), info/error/fatal/success/warn, debug toggle
# ==================================================================================================

# Global debug flag (string "true"|"false")
declare -g NDS_DEBUG=${NDS_DEBUG:-0}

# ------------------------------------------------------------------------------
# Basic console helpers (write to stderr)
# ------------------------------------------------------------------------------
console() { printf "%s\n" "${1:-}" >&2; }
consolef() { printf "%s\n" "${1:-}" >&2; }
new_line() { printf "\n" >&2; }


# ------------------------------------------------------------------------------
# Core logging function
# ------------------------------------------------------------------------------
# Usage: log "<prefix>" "<message>"
log() {
    local prefix="${1:-}"
    local message="$2"
    local ts
    printf -v ts '%(%Y-%m-%d %H:%M:%S)T' -1 2>/dev/null
    printf " %s %s %s\n" "$ts" "$prefix" "$message" >&2
}

# Friendly wrappers
info()    { log "ℹ️  [INFO] -" "$1"; }
error()   { log "❌ [FAIL] -" "$1"; }
fatal()   { log "❌ [FATAL] -" "$1"; }
success() { log "✅ [PASS] -" "$1"; }
warn()    { log "⚠️  [WARN] -" "$1"; }
validation_error() { log "❌ [VALIDATION] -" "$1"; }

# ------------------------------------------------------------------------------
# Debugging controls and output
# ------------------------------------------------------------------------------
# Usage: debug_enable, debug_disable, debug_toggle, debug_is_enabled
debug_enable()  { NDS_DEBUG=1; log "🐛 [DEBUG]" "Debug enabled"; }
debug_disable() { NDS_DEBUG=0; log "🐛 [DEBUG]" "Debug disabled"; }
debug_set()  { if [[ "$1" == "true" ]]; then debug_enable; else debug_disable; fi; }
debug_is_enabled() { ((NDS_DEBUG)); }

# Debug print — only prints when enabled
debug() { ((NDS_DEBUG)) && log "🐛 [DEBUG] -" "$1"; }

# # Debug ENV control
# [[ "${NDS_DEBUG}" == "true" ]] && debug_enable
# [[ "${NDS_DEBUG}" == "false" ]] && debug_disable
