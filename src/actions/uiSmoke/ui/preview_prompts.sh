#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI smoke action (preview)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-07
# ==================================================================================================

action_preview() {
    nds_ui_h "UI smoke — walk every prompt (no install)"
    nds_ui_b ""
    nds_ui_b "Interactive only. You will click through:"
    nds_ui_i "shared yes/no/back + numbered menu digit"
    nds_ui_i "settingsManager field prompts (toggle, string, IP, hostname, …)"
    nds_ui_i "install/app confirms (fake disk/IP — no format, no wipe)"
    nds_ui_i "git title-collision ask (message only — no gh API)"
    nds_ui_b ""
    nds_ui_b "Will NOT: partition disks, nixos-install, clone flakes, or call GitHub."
    nds_ui_b ""
}
