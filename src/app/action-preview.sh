#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action preview helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Shared app preview and confirmation helpers for action flows
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

# Description: Run the action preview and handle proceed/back responses.
nds_action_run_preview() {
    declare -f action_preview &>/dev/null || { error "action_preview() not found"; return 1; }

    if nds_skip_menu NDS_ACTION_PREVIEW_SKIP; then
        log "Action preview skipped (NDS_ACTION_PREVIEW_SKIP)"
        return 0
    fi

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
