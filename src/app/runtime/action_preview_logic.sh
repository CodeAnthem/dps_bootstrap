#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action preview helpers (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-06
# Description:   Preview skip rules; UI lives in app/ui/action_preview_prompts.sh
# ==================================================================================================

# Description: Run the action preview and handle proceed/back responses.
nds_action_run_preview() {
    declare -f action_preview &>/dev/null || { error "action_preview() not found"; return 1; }

    if nds_skip_menu NDS_ACTION_PREVIEW_SKIP; then
        log "Action preview skipped (NDS_ACTION_PREVIEW_SKIP)"
        return 0
    fi

    nds_mode_resolve || true
    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        log "Action preview skipped (NDS_MODE=unattended)"
        return 0
    fi

    nds_app_ui_run_action_preview
}
