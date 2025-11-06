#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-06
# Description:   Handles safe import of libraries (.sh files)
# Feature:       Syntax validation, recursive directory import, and error aggregation
# ==================================================================================================

declare -g NDS_IMPORT_ERRORS="" # Global variable to store import errors

# --------------------------------------------------------------------------------------------------
# Public: Import a single file with validation
# Usage: nds_import_file <filepath>
# --------------------------------------------------------------------------------------------------
nds_import_file() {
    local filePath="$1"

    if [[ ! -f "$filePath" ]]; then
        echo "Error: File not found: $filePath" >&2
        return 1
    fi

    NDS_IMPORT_ERRORS="" # Reset previous errors

    _nds_import_and_validate_file "$filePath"
    _nds_import_showErrors
}

# --------------------------------------------------------------------------------------------------
# Public: Import all .sh files from a directory excluding "_" prefixed files
# Usage: nds_import_dir <directory> [recursive]
# If recursive=true, it will also import subdirectories
# --------------------------------------------------------------------------------------------------
nds_import_dir() {
    local directory="${1:-}"
    local recursive="${2:-false}"
    local item baseName hadError=false

    # Validate directory
    if [[ ! -d "$directory" ]]; then
        echo "Error: Directory not found: $directory" >&2
        return 1
    fi

    # Validate recursive flag
    if [[ "$recursive" != "true" && "$recursive" != "false" ]]; then
        echo "Error: Invalid recursive parameter: $recursive (expected true or false)" >&2
        return 1
    fi

    NDS_IMPORT_ERRORS="" # Reset previous errors

    for item in "$directory"/*; do
        [[ -e "$item" ]] || continue
        baseName="$(basename "$item")"

        # Skip hidden or internal files
        [[ "${baseName:0:1}" == "_" ]] && continue

        if [[ -d "$item" && "$recursive" == "true" ]]; then
            nds_import_dir "$item" "$recursive" || hadError=true
            continue
        fi

        # Only process *.sh files
        if [[ "${baseName##*.}" == "sh" ]]; then
            _nds_import_and_validate_file "$item" || hadError=true
        fi
    done

    # Display errors if any
    if [[ "$hadError" == "true" ]]; then
        _nds_import_showErrors
        return 1
    fi
    return 0
}

# --------------------------------------------------------------------------------------------------
# Private: Validate and import a single file
# Usage: _nds_import_and_validate_file <filepath>
# --------------------------------------------------------------------------------------------------
_nds_import_and_validate_file() {
    local filePath="$1"
    local errOutput line cleaned=""

    # Validate syntax in isolated shell
    if ! errOutput=$(bash -n "$filePath" 2>&1); then
        while IFS= read -r line; do
            [[ "$line" == "$filePath:"* ]] && line="${line#"$filePath: "}"
            cleaned+=$'\n'" -> $line"
        done <<< "$errOutput"

        NDS_IMPORT_ERRORS+=$'\n'"[Validation Error] $filePath:${cleaned}"
        return 1
    fi

    # shellcheck disable=SC1090
    if ! source "$filePath"; then
        NDS_IMPORT_ERRORS+=$'\n'"[Source Error] $filePath"
        return 1
    fi

    return 0
}

# --------------------------------------------------------------------------------------------------
# Private: Display collected import errors and clear buffer
# Usage: _nds_import_showErrors
# --------------------------------------------------------------------------------------------------
_nds_import_showErrors() {
    if [[ -n "$NDS_IMPORT_ERRORS" ]]; then
        echo "${NDS_IMPORT_ERRORS#"$'\n'"}" >&2
        NDS_IMPORT_ERRORS=""
        return 1
    fi
    return 0
}
