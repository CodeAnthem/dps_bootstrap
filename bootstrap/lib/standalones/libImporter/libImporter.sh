#!/usr/bin/env bash
# ==================================================================================================
# Library Importer - Standalone Feature
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-12
# Description:   Safe library import with syntax validation and error aggregation
# Feature:       File/directory import, recursive scanning, named folder import
# ==================================================================================================
# shellcheck disable=SC1090  # Can't follow non-constant source
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

declare -g __IMPORT_ERRORS=""                                 # Buffer for accumulated import errors

# ==================================================================================================
# PUBLIC FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Public: Import a single file with syntax validation
# Usage: import_file <filepath>
# Returns: 0 on success, 1 on failure
import_file() {
    local file_path="$1"
    
    if [[ -z "$file_path" ]]; then
        error "Usage: import_file <filepath>"
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        error "File not found: $file_path"
        return 1
    fi
    
    __IMPORT_ERRORS=""  # Reset previous errors
    
    __import_validate_and_source "$file_path"
    __import_show_errors
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Import all .sh files from a directory (excluding underscore-prefixed files)
# Usage: import_dir <directory> [recursive]
# Parameters:
#   directory - Path to directory to scan
#   recursive - "true" to recurse into subdirectories, "false" otherwise (default: false)
# Returns: 0 on success, 1 if any file failed
import_dir() {
    local directory="${1:-}"
    local recursive="${2:-false}"
    local item base_name had_error=false
    
    if [[ -z "$directory" ]]; then
        error "Usage: import_dir <directory> [recursive]"
        return 1
    fi
    
    # Validate directory
    if [[ ! -d "$directory" ]]; then
        error "Directory not found: $directory"
        return 1
    fi
    
    # Validate recursive flag
    if [[ "$recursive" != "true" && "$recursive" != "false" ]]; then
        error "Invalid recursive parameter: $recursive (expected true or false)"
        return 1
    fi
    
    __IMPORT_ERRORS=""  # Reset previous errors
    
    for item in "$directory"/*; do
        [[ -e "$item" ]] || continue
        base_name="$(basename "$item")"
        
        # Skip hidden or internal files (starting with underscore)
        [[ "${base_name:0:1}" == "_" ]] && continue
        
        if [[ -d "$item" && "$recursive" == "true" ]]; then
            import_dir "$item" "$recursive" || had_error=true
            continue
        fi
        
        # Only process *.sh files
        if [[ "${base_name##*.}" == "sh" ]]; then
            __import_validate_and_source "$item" || had_error=true
        fi
    done
    
    # Display errors if any
    if [[ "$had_error" == "true" ]]; then
        __import_show_errors
        return 1
    fi
    return 0
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Import a file named after its parent folder
# Usage: import_named <folder_path>
# Example: import_named /path/to/mymodule  -> sources /path/to/mymodule/mymodule.sh
# Returns: 0 on success, 1 on failure
import_named() {
    local folder_path="${1:-}"
    local folder_name file_path
    
    if [[ -z "$folder_path" ]]; then
        error "Usage: import_named <folder_path>"
        return 1
    fi
    
    # Validate it's a directory
    if [[ ! -d "$folder_path" ]]; then
        error "Directory not found: $folder_path"
        return 1
    fi
    
    # Get folder name
    folder_name="$(basename "$folder_path")"
    
    # Construct expected file path
    file_path="${folder_path}/${folder_name}.sh"
    
    # Check if file exists
    if [[ ! -f "$file_path" ]]; then
        error "Named file not found: $file_path"
        return 1
    fi
    
    debug "Importing named file: $file_path"
    
    __IMPORT_ERRORS=""  # Reset previous errors
    
    __import_validate_and_source "$file_path"
    __import_show_errors
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Public: Check if a file has valid Bash syntax without sourcing it
# Usage: import_validate <filepath>
# Returns: 0 if valid, 1 if syntax errors found
import_validate() {
    local file_path="$1"
    local err_output
    
    if [[ -z "$file_path" ]]; then
        error "Usage: import_validate <filepath>"
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        error "File not found: $file_path"
        return 1
    fi
    
    # Validate syntax in isolated shell
    if ! err_output=$(bash -n "$file_path" 2>&1); then
        error "Syntax validation failed for: $file_path"
        printf "%s\n" "$err_output" >&2
        return 1
    fi
    
    debug "Syntax validation passed: $file_path"
    return 0
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# PRIVATE FUNCTIONS
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Private: Validate and source a single file
# Usage: __import_validate_and_source <filepath>
# Returns: 0 on success, 1 on failure (errors stored in __IMPORT_ERRORS)
__import_validate_and_source() {
    local file_path="$1"
    local err_output line cleaned=""
    
    debug "Validating and sourcing: $file_path"
    
    # Validate syntax in isolated shell
    if ! err_output=$(bash -n "$file_path" 2>&1); then
        while IFS= read -r line; do
            [[ "$line" == "$file_path:"* ]] && line="${line#"$file_path: "}"
            cleaned+=$'\n'" -> $line"
        done <<< "$err_output"
        
        __IMPORT_ERRORS+=$'\n'"[Validation Error] $file_path:${cleaned}"
        return 1
    fi
    
    # Source the file
    if ! source "$file_path"; then
        __IMPORT_ERRORS+=$'\n'"[Source Error] $file_path"
        return 1
    fi
    
    debug "Successfully sourced: $file_path"
    return 0
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Private: Display collected import errors and clear buffer
# Usage: __import_show_errors
# Returns: 1 if errors exist, 0 if buffer is empty
__import_show_errors() {
    if [[ -n "$__IMPORT_ERRORS" ]]; then
        printf "%s\n" "${__IMPORT_ERRORS#"$'\n'"}" >&2
        __IMPORT_ERRORS=""
        return 1
    fi
    return 0
}
# --------------------------------------------------------------------------------------------------
