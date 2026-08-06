#!/usr/bin/env bash
# ==================================================================================================
# NDS - App UI: action preview
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-06
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_ACTION_PREVIEW_SKIP

# Description: Render a comma-separated list of action items as indented UI lines.
# Arguments:
# - items: <String> Comma-separated item list
nds_action_items() {
    local items="$1"
    local item
    IFS=',' read -ra _items <<< "$items"
    for item in "${_items[@]}"; do
        nds_ui_i "$(nds_trim "$item")"
    done
}

# Description: Show preview header, run action_preview, ask proceed/back.
# Returns:
# - 0 proceed; NDS_ACTION_BACK back; 130 abort
nds_app_ui_run_action_preview() {
    nds_ui_section_header "Install preview"
    action_preview
    nds_ui_b "Press Y to continue, B to go back to the action menu."
    nds_ui_b ""
    nds_ask_user_continue "Proceed with this action?"
    local prc=$?
    case "$prc" in
        0) return 0 ;;
        2) return "$NDS_ACTION_BACK" ;;
        *) return 130 ;;
    esac
}
