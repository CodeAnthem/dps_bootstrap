#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-07-07
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

action_presets() {
    printf '%s\n' installFlake boot disk encryption platform
}

action_config() {
    nds_configurator_preset_set_display installFlake "Your flake"
    nds_configurator_preset_set_priority installFlake 20
    nds_configurator_preset_set_priority boot 21
    nds_configurator_preset_set_priority disk 22
    nds_configurator_preset_set_priority encryption 23
    nds_configurator_preset_set_priority platform 24
}

action_preview() {
    nds_ui_h "Install NixOS from your flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "install mode (local live ISO or remote nixos-anywhere)"
    nds_ui_i "flake location (git URL or path, auto-detected), host name, host directory"
    nds_ui_i "bootloader (UEFI mode + GRUB / systemd-boot / rEFInd), disk (local mode)"
    nds_ui_b ""
    nds_ui_b "For a private repo, NDS probes SSH access to the root flake and each"
    nds_ui_b "locked git input (from flake.lock) before partitioning."
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "local: partition via disko or NDS, generate facter.json, run nixos-install --flake"
    nds_ui_i "remote: delegate to nixos-anywhere (disko + nixos-facter + install)"
    nds_ui_i "offer an install backup zip; reboot when done (local only)"
    nds_ui_b ""
}

action_setup() {
    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu_or_skip || exit 12
    nds_flake_install_prepare_and_verify || exit 11
    nds_flake_install_confirm || exit 13

    local install_mode
    install_mode="$(nds_configurator_config_get INSTALL_MODE)"
    install_mode="${install_mode:-local}"

    section_header "NixOS installation"
    nds_install_log "installFlake: action starting (mode=${install_mode})"
    nds_nixos_install_flake || exit 15
    export NDS_GIT_INSTALL_SUCCEEDED=true
    nds_git_access_cleanup_success

    if [[ "$install_mode" == "remote" ]]; then
        nds_install_remote_finish || exit 16
    else
        nds_install_finish || exit 16
    fi
}
