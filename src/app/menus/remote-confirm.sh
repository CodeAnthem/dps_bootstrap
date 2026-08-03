#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote install confirmation screen
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-03
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_REMOTE_CONFIRM_SKIP

# Description: Show the remote install warning screen and ask the user to confirm.
# Arguments:
# - target_ip: <String> Remote host IP or hostname
# - extra:     <String|optional> Extra message line
nds_action_confirm_remote_install() {
    local target_ip="$1"
    local extra="${2:-}"
    local flake_host flake_path flake_source

    nds_ui_section_header "Ready to install (remote)"
    nds_ui_b "Review the summary below. Installation does not start until you confirm at the end."
    nds_ui_b ""

    flake_host="${NDS_FLAKE_HOST:-$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)}"
    flake_path="${NDS_FLAKE_INSTALL_PATH:-$(nds_cfg_get FLAKE_INSTALL_PATH 2>/dev/null || true)}"
    flake_path="${flake_path:-/mnt/etc/nixos}"
    flake_source="${NDS_FLAKE_SOURCE:-$(nds_cfg_get FLAKE_SOURCE 2>/dev/null || true)}"
    if [[ -n "$flake_host" ]]; then
        nds_ui_h "Flake target"
        nds_ui_i "${flake_path}#${flake_host} (source: ${flake_source:-remote}, mode: remote)"
        nds_ui_b ""
    fi

    nds_ui_h "Target host"
    nds_ui_i "root@${target_ip} — disk will be partitioned and all data erased"
    nds_ui_b ""

    nds_ui_h "Steps"
    nds_ui_i "1. Clone or use your flake on this machine"
    nds_ui_i "2. Run nixos-anywhere (disko + nixos-facter + install)"
    nds_ui_i "3. Commit generated facter.json to your flake repo"
    nds_ui_b ""

    [[ -n "$extra" ]] && nds_ui_b "$extra" && nds_ui_b ""

    if nds_skip_menu NDS_REMOTE_CONFIRM_SKIP; then
        log "Remote install confirmation skipped"
        return 0
    fi
    nds_ask_user_to_proceed "Start remote installation now" || return 1
    return 0
}
