#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI smoke action (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-07
# Description:   Drive nds_uismoke_walk — human clicks through every core prompt
# ==================================================================================================

action_config() {
    nds_cfg_preset_disable disk
    nds_cfg_preset_disable quick
    nds_cfg_preset_disable region
    nds_cfg_preset_disable network
    nds_cfg_preset_disable boot
    nds_cfg_preset_disable access
    nds_cfg_preset_disable encryption
    nds_cfg_preset_disable platform
    nds_cfg_preset_disable installFlake
    nds_cfg_preset_disable remoteAction
}

action_setup() {
    nds_mode_resolve || true
    if nds_mode_is_unattended; then
        error "uiSmoke is interactive only — unset NDS_MODE/NDS_UNATTENDED/NDS_AUTO_CONFIRM"
        exit 11
    fi
    nds_uismoke_walk || exit 1
    success "UI smoke walk finished"
}
