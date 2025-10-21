#!/usr/bin/env bash
# ==================================================================================================
# File:          validation_common.sh
# Description:   Common validation functions used across multiple modules
# Author:        DPS Project
# ==================================================================================================

# Validate yes/no input
# Usage: validate_yes_no "y"
validate_yes_no() {
    local input="$1"
    local normalized="${input,,}"
    [[ "$normalized" =~ ^(y|yes|n|no)$ ]]
}

# Validate timezone
# Usage: validate_timezone "UTC" or validate_timezone "Europe/Berlin"
validate_timezone() {
    local tz="$1"
    
    # Check if timezone exists
    if [[ -f "/usr/share/zoneinfo/$tz" ]]; then
        return 0
    fi
    
    # Common timezone abbreviations
    case "$tz" in
        UTC|GMT|EST|PST|MST|CST) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate username
# Usage: validate_username "admin"
validate_username() {
    local username="$1"
    # Linux username rules: start with letter/underscore, contain letters/numbers/underscore/dash
    local username_regex='^[a-z_][a-z0-9_-]{0,31}$'
    [[ "$username" =~ $username_regex ]]
}

# Validate file path exists
# Usage: validate_file_path "/path/to/file"
validate_file_path() {
    local path="$1"
    [[ -f "$path" ]]
}

# Validate directory path exists
# Usage: validate_dir_path "/path/to/dir"
validate_dir_path() {
    local path="$1"
    [[ -d "$path" ]]
}

# Validate choice from options
# Usage: validate_choice "dhcp" "dhcp|static"
validate_choice() {
    local value="$1"
    local options="$2"
    
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        if [[ "$value" == "$choice" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate role for node configuration
# Usage: validate_role "worker"
validate_role() {
    local role="$1"
    local valid_roles=("worker" "gateway" "gpu-worker")
    
    for valid_role in "${valid_roles[@]}"; do
        if [[ "$role" == "$valid_role" ]]; then
            return 0
        fi
    done
    return 1
}
