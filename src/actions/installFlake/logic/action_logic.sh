#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-06
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

action_presets() {
    # platform (VM guest tools) is classicInstall-only — flake hosts use facter + flake modules
    printf '%s\n' installFlake boot disk encryption
}

action_config() {
    nds_cfg_preset_set_display installFlake "Your flake"
    nds_cfg_preset_set_priority installFlake 20
    nds_cfg_preset_set_priority boot 21
    nds_cfg_preset_set_priority disk 22
    nds_cfg_preset_set_priority encryption 23
}

action_setup() {
    nds_mode_resolve || true

    # Early gate: URL → git → hosts → target (before full settings menu)
    nds_action_call_feature nds_flake_install_gate || exit 11

    if ! nds_cfg_validate_all; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_cfg_validate_all || exit 11
    fi

    nds_cfg_menu_or_skip || exit 12

    # Auth already done in the early gate — export flake env + disko detect only
    nds_flake_install_prepare_and_verify || exit 11
    nds_flake_install_confirm || exit 13

    local install_mode
    install_mode="$(nds_cfg_get INSTALL_MODE)"
    install_mode="${install_mode:-local}"

    nds_install_ui_section_nixos_install
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
