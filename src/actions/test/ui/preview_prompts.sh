#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test action (UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-06
# ==================================================================================================

action_preview() {
    nds_ui_h "NDS self-tests (read-only)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "nothing — no install settings required"
    nds_ui_b ""
    nds_ui_b "NDS will:"
    nds_action_items "run cfg tests, run inputs tests, run classicConfig tests"
    nds_ui_b ""
}
