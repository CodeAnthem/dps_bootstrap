#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Handles libraries import
# Feature:       Safe import of .sh files
# ==================================================================================================

declare -g NDS_IMPORT_ERRORS="" # Global variable to store import errors

# ----------------------------------------------------------------------------------
# Safe import functions
# ----------------------------------------------------------------------------------
# Import a single file with validation
# Usage: nds_import_file <filepath>
# Returns: 0 on success, 1 on failure (with errors displayed)
nds_import_file() {
    local filepath="$1"

    if [[ ! -f "$filepath" ]]; then
        echo "Error: File not found: $filepath" >&2
        return 1
    fi

    NDS_IMPORT_ERRORS=""  # Clear previous errors
    _nds_import_and_validate_file "$filepath"
    _nds_import_showErrors
}

# Import all .sh files from a directory
# Usage: nds_import_dir <directory> [recursive]
# If recursive is "true" will descend into subdirectories (skipping names beginning with "_").
# Returns: 0 on success, 1 if any file failed
nds_import_dir() {
    local directory recursive item basename
    local had_error=false

    directory="${1:-}"
    [[ -d "$directory" ]] || {
        echo "Error: Directory not found: $directory" >&2
        return 1
    }

    recursive="${2:-false}"
    [[ "$recursive" == "true" || "$recursive" == "false" ]] || {
        echo "Error: Invalid recursive parameter: $recursive" >&2
        return 1
    }

    NDS_IMPORT_ERRORS=""  # Clear previous errors
    local had_error=false

    for item in "$directory"/*; do
        [[ -e "$item" ]] || continue   # Skip when glob doesn't match (empty dir)

        basename="$(basename "$item")"

        # Skip files/folders starting with underscore
        [[ "${basename:0:1}" == "_" ]] && continue

        # If directory, maybe recurse
        if [[ -d "$item" ]]; then
            if [[ "$recursive" == "true" ]]; then
                nds_import_dir "$item" "$recursive" || return 1
            fi
            continue
        fi

        # Only consider .sh files
        if [[ "${basename: -3}" == ".sh" ]]; then
            if ! _nds_import_and_validate_file "$item"; then
                had_error=true
            fi
        fi
    done

    # Show collected errors and return status
    if [[ "$had_error" == "true" ]]; then
        _nds_import_showErrors
        return 1
    fi

    return 0
}

# ----------------------------------------------------------------------------------
# Private helpers
# ----------------------------------------------------------------------------------
# Internal function: Validate and import a single file
# Usage: _nds_import_and_validate_file <filepath>
# Returns: 0 on success, 1 on failure (errors stored in NDS_IMPORT_ERRORS)
_nds_import_and_validate_file() {
    local filepath="$1"
    local err_output

    # Validate by running in a strict subshell and capture stderr output
    if ! err_output=$(bash -n "$filepath" 2>&1); then
        # Clean the path prefix "$filepath: " from each line
        local cleaned=""
        local line
        while IFS= read -r line; do
            if [[ "$line" == "$filepath:"* ]]; then
                line="${line#"$filepath: "}"
            fi
            cleaned+=$'\n'" -> $line"
        done <<< "$err_output"

        # Store error in global variable
        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to validate: $filepath${cleaned}"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to validate: $filepath${cleaned}"
        fi
        return 1
    fi

    # Source in current shell (affects parent environment)
    # shellcheck disable=SC1090
    if ! source "$filepath"; then
        # Store source error in global variable
        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to source: $filepath"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to source: $filepath"
        fi
        return 1
    fi

    return 0
}

# Display collected import errors and clear the error buffer
# Usage: _nds_import_showErrors
# Returns: 0 if no errors, 1 if errors were present
_nds_import_showErrors() {
    if [[ -n "$NDS_IMPORT_ERRORS" ]]; then
        echo "$NDS_IMPORT_ERRORS" >&2
        NDS_IMPORT_ERRORS=""  # Clear errors after showing
        return 1
    fi
    return 0
}
