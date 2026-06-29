#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Action overview screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2026-06-29
# Description:   Formatted intro blocks shown before each install action wizard
# ==================================================================================================

nds_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

nds_action_overview() {
    local title="$1"
    local youwill="$2"
    local ndswill="$3"
    local item

    nds_ui_h "$title"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    IFS=',' read -ra _items <<< "$youwill"
    for item in "${_items[@]}"; do
        nds_ui_b "- $(nds_trim "$item")"
    done
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    IFS=',' read -ra _items <<< "$ndswill"
    for item in "${_items[@]}"; do
        nds_ui_b "- $(nds_trim "$item")"
    done
    nds_ui_b ""
}
