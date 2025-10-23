#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Validation Library - Common
# Feature:       Common validation functions used across multiple contexts
# ==================================================================================================

# =============================================================================
# GENERIC VALIDATION
# =============================================================================

# Validate non-empty string
# Usage: validate_nonempty "some value"
validate_nonempty() { [[ -n "$1" ]]; }

# Validate disk size format (e.g., 8G, 500M, 1T)
# Usage: validate_disk_size "8G"
validate_disk_size() {
    local size="$1"
    [[ "$size" =~ ^[0-9]+[KMGT]?$ ]]
}
