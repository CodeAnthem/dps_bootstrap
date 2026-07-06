#!/usr/bin/env bash
# ==================================================================================================
# NDS - Menu: remote install confirmation screen
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

nds_action_confirm_remote_install() {
    local target_ip="$1"
    local extra="${2:-}"

    section_header "Ready to install (remote)"
    nds_ui_b "Review the summary below. Installation does not start until you confirm at the end."
    nds_ui_b ""

    nds_ui_h "Target host"
    nds_ui_i "root@${target_ip} — disk will be partitioned and all data erased"
    nds_ui_b ""

    nds_ui_h "Steps"
    nds_ui_i "1. Clone or use your flake on this machine"
    nds_ui_i "2. Run nixos-anywhere (disko + nixos-facter + install)"
    nds_ui_i "3. Commit generated facter.json to your flake repo"
    nds_ui_b ""

    [[ -n "$extra" ]] && nds_ui_b "$extra" && nds_ui_b ""

    nds_askUserToProceed "Start remote installation now" || return 1
    return 0
}
