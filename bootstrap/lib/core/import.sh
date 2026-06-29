#!/usr/bin/env bash
# ==================================================================================================
# NDS - Module import utilities
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Validate and source NDS library files
# ==================================================================================================

declare -g NDS_IMPORT_ERRORS=""

_nds_import_and_validate_file() {
    local filepath="$1"
    local err_output

    if ! err_output=$(bash -euo pipefail "$filepath" 2>&1); then
        local cleaned=""
        local line
        while IFS= read -r line; do
            if [[ "$line" == "$filepath:"* ]]; then
                line="${line#"$filepath: "}"
            fi
            cleaned+=$'\n'" -> $line"
        done <<< "$err_output"

        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to validate: $filepath${cleaned}"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to validate: $filepath${cleaned}"
        fi
        return 1
    fi

    # shellcheck disable=SC1090
    if ! source "$filepath"; then
        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to source: $filepath"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to source: $filepath"
        fi
        return 1
    fi

    return 0
}

_nds_import_showErrors() {
    if [[ -n "$NDS_IMPORT_ERRORS" ]]; then
        echo "$NDS_IMPORT_ERRORS" >&2
        NDS_IMPORT_ERRORS=""
        return 1
    fi
    return 0
}

nds_import_file() {
    local filepath="$1"

    [[ -f "$filepath" ]] || {
        echo "Error: File not found: $filepath" >&2
        return 1
    }

    NDS_IMPORT_ERRORS=""
    _nds_import_and_validate_file "$filepath"
    _nds_import_showErrors
}

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

    NDS_IMPORT_ERRORS=""
    had_error=false

    for item in "$directory"/*; do
        [[ -e "$item" ]] || continue

        basename="$(basename "$item")"
        [[ "${basename:0:1}" == "_" ]] && continue

        if [[ -d "$item" ]]; then
            if [[ "$recursive" == "true" ]]; then
                nds_import_dir "$item" "$recursive" || return 1
            fi
            continue
        fi

        if [[ "${basename: -3}" == ".sh" ]]; then
            if ! _nds_import_and_validate_file "$item"; then
                had_error=true
            fi
        fi
    done

    if [[ "$had_error" == "true" ]]; then
        _nds_import_showErrors
        return 1
    fi

    return 0
}

# Load core + feature libraries without running the interactive bootstrap.
# Usage: nds_bootstrap_load_libs
nds_bootstrap_load_libs() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"
    local lib_dir="${script_dir}/lib"

    nds_import_file "${lib_dir}/core/ui.sh" || return 1
    nds_import_dir "${lib_dir}/core" false || return 1
    nds_ui_init
    nds_import_file "${lib_dir}/load.sh" || return 1
    nds_configurator_init || return 1
    nds_installation_init || return 1
    return 0
}
