#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install layer selfchecks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

nds_install_aa_bridge_selfcheck() {
    declare -f nds_cfg_aa_from_store &>/dev/null || return 1
    declare -f nds_feature_require_keys &>/dev/null || return 1
    declare -f nds_mode_is_unattended &>/dev/null || return 1
    local -A cfg=([DISK_TARGET]="/dev/sda")
    nds_feature_require_keys cfg DISK_TARGET || return 1
    return 0
}
