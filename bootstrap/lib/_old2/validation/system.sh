#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Validation Library - System
# Feature:       System-related validation functions (username, URL, path)
# ==================================================================================================

# =============================================================================
# USER/SYSTEM VALIDATION
# =============================================================================

# Validate username (Linux username rules)
# Usage: validate_username "admin"
validate_username() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }

# Validate URL format
# Usage: validate_url "https://github.com/repo.git"
validate_url() {
    local url="$1"
    [[ "$url" =~ ^(https?|git|ssh):// ]]
}

# Validate path format (absolute or relative)
# Usage: validate_path "/root/.ssh/key"
validate_path() {
    local path="$1"
    # Accept absolute paths, ~ paths, or ./relative paths
    [[ "$path" =~ ^(/|~|\.) ]]
}

# Validate file exists
# Usage: validate_file_path "/path/to/file"
validate_file_path() { [[ -f "$1" ]]; }

# Validate directory exists
# Usage: validate_dir_path "/path/to/dir"
validate_dir_path() { [[ -d "$1" ]]; }
