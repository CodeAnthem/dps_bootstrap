#!/usr/bin/env bash
# ==================================================================================================
# NDS - Module import utilities
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Validate and source NDS library files
# ==================================================================================================

declare -g NDS_IMPORT_ERRORS=""

_core_import_and_validate_file() {
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

_core_import_show_errors() {
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
    _core_import_and_validate_file "$filepath"
    _core_import_show_errors
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
            if ! _core_import_and_validate_file "$item"; then
                had_error=true
            fi
        fi
    done

    if [[ "$had_error" == "true" ]]; then
        _core_import_show_errors
        return 1
    fi

    return 0
}

# Load .sh files in a directory (non-recursive), alphabetical, skip _* and load.sh.
_nds_import_dir_files() {
    local directory="$1"
    local item basename
    local had_error=false
    local -a files=()

    [[ -d "$directory" ]] || return 0
    for item in "$directory"/*; do
        [[ -f "$item" ]] || continue
        basename="$(basename "$item")"
        [[ "${basename:0:1}" == "_" ]] && continue
        [[ "$basename" == "load.sh" ]] && continue
        [[ "${basename: -3}" == ".sh" ]] || continue
        files+=("$item")
    done
    if ((${#files[@]} == 0)); then
        return 0
    fi
    local _save_ifs="$IFS"
    IFS=$'\n'
    # shellcheck disable=SC2207
    files=($(printf '%s\n' "${files[@]}" | sort))
    IFS="$_save_ifs"
    for item in "${files[@]}"; do
        if ! _core_import_and_validate_file "$item"; then
            had_error=true
        fi
    done
    [[ "$had_error" == "true" ]] && return 1
    return 0
}

# Description: Recursively load a feature tree without nested load.sh.
# Order: preferred dirs (lib → logic → ui) then other dirs alpha; files alpha within.
# Skips: tests/, data/, fixtures/, specs/, load.sh, _*
# Arguments:
# - root: <String> Feature directory
nds_import_tree() {
    local root="${1:?feature root}"
    local -a preferred=(lib logic state ui)
    local -a other_dirs=()
    local d name preferred_set=" lib logic state ui "
    local had_error=false

    [[ -d "$root" ]] || {
        echo "Error: Directory not found: $root" >&2
        return 1
    }

    NDS_IMPORT_ERRORS=""
    _nds_import_dir_files "$root" || had_error=true

    for name in "${preferred[@]}"; do
        d="${root}/${name}"
        [[ -d "$d" ]] || continue
        if ! nds_import_tree "$d"; then
            had_error=true
        fi
    done

    for d in "$root"/*; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        [[ "${name:0:1}" == "_" ]] && continue
        case "$name" in
            tests|data|fixtures|specs) continue ;;
        esac
        [[ "$preferred_set" == *" $name "* ]] && continue
        other_dirs+=("$d")
    done
    if ((${#other_dirs[@]})); then
        local _save_ifs="$IFS"
        IFS=$'\n'
        # shellcheck disable=SC2207
        other_dirs=($(printf '%s\n' "${other_dirs[@]}" | sort))
        IFS="$_save_ifs"
        for d in "${other_dirs[@]}"; do
            if ! nds_import_tree "$d"; then
                had_error=true
            fi
        done
    fi

    if [[ "$had_error" == "true" ]]; then
        _core_import_show_errors
        return 1
    fi
    return 0
}

# Load core + feature libraries without running the interactive bootstrap.
nds_bootstrap_load_libs() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"
    nds_import_file "${script_dir}/app/lifecycle.sh" || return 1
    nds_lifecycle_load_core "$script_dir" || return 1
    nds_lifecycle_load_ui "$script_dir" || return 1
    nds_lifecycle_load_actions "$script_dir" || return 1
    nds_import_file "${script_dir}/app/bootstrap.sh" || return 1
}

