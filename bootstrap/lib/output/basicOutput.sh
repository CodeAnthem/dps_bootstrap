#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-11-06
# Description:   General output and logging helpers + debug management
# Feature:       Timestamped logs (no subshell), info/error/fatal/success/warn, debug toggle
# ==================================================================================================

# ------------------------------------------------------------------------------
# Basic console helpers (write to stderr)
# ------------------------------------------------------------------------------
console() { printf "%s\n" "${1:-}" >&2; }
consolef() { printf "%s\n" "${1:-}" >&2; }
new_line() { printf "\n" >&2; }
