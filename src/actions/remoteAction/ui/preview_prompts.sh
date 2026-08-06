#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action from target flake (UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-06
# ==================================================================================================

action_preview() {
    nds_ui_h "Run a custom install action from your flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "flake Git URL, host name, host directory, hardware placement, disk"
    nds_ui_i "plus any extra fields from your flake's .nds/presets/"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "clone the flake and inject custom preset hooks from .nds/"
    nds_ui_i "run your install script (or fall back to a standard flake install)"
    nds_ui_i "reboot when done"
    nds_ui_b ""
}
