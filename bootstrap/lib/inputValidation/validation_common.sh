#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Common validation functions used across multiple modules
# ==================================================================================================

# =============================================================================
# BASIC VALIDATION FUNCTIONS
# =============================================================================

# Validate yes/no input
# Usage: validate_yes_no "y"
validate_yes_no() { 
    local normalized="${1,,}"
    [[ "$normalized" =~ ^(y|yes|n|no)$ ]]
}

# Validate non-empty string
# Usage: validate_nonempty "some value"
validate_nonempty() {
    [[ -n "$1" ]]
}

# =============================================================================
# USER/SYSTEM VALIDATION FUNCTIONS
# =============================================================================

# Validate username (Linux username rules)
# Usage: validate_username "admin"
validate_username() { 
    [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

# Validate timezone
# Usage: validate_timezone "UTC" or validate_timezone "Europe/Berlin"
validate_timezone() {
    local tz="$1"
    
    # Check if timezone exists
    [[ -f "/usr/share/zoneinfo/$tz" ]] && return 0
    
    # Common timezone abbreviations
    case "$tz" in
        UTC|GMT|EST|PST|MST|CST) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# PATH VALIDATION FUNCTIONS
# =============================================================================

# Validate file path exists
# Usage: validate_file_path "/path/to/file"
validate_file_path() { [[ -f "$1" ]]; }

# Validate directory path exists
# Usage: validate_dir_path "/path/to/dir"
validate_dir_path() { [[ -d "$1" ]]; }

# Validate general path (doesn't need to exist)
# Usage: validate_path "/path/to/something"
validate_path() {
    [[ "$1" =~ ^/ || "$1" =~ ^~/ || "$1" =~ ^\. ]]
}

# Validate URL format
# Usage: validate_url "https://github.com/user/repo.git"
validate_url() {
    [[ "$1" =~ ^(https?|git|ssh):// ]]
}
