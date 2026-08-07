#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test action (UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-07
# ==================================================================================================

action_preview() {
    nds_ui_h "NDS self-tests (read-only)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "nothing — no install settings required"
    nds_ui_b ""
    nds_ui_b "NDS will:"
    nds_action_items "run the full CI selftest suite (structure, validators, git, tools, install helpers, …)"
    nds_ui_b ""
    nds_ui_b "For interactive prompt walking use action uiSmoke (also needs NDS_TEST=true)."
    nds_ui_b ""
}
