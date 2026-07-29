#!/usr/bin/env bash
# ==================================================================================================
# NDS - String utilities
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Pure string helpers shared across features and UI
# ==================================================================================================

# Description: Strip leading and trailing whitespace from a string.
# Arguments:
# - s: <String> Input string
# Returns:
# - <String> Trimmed string on stdout
nds_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}
