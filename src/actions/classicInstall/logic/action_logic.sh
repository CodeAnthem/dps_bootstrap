#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-06
# Description:   Install NixOS with a generated /etc/nixos configuration (no flake needed)
# ==================================================================================================

action_presets() {
    printf '%s\n' quick region network boot access disk encryption platform
}

action_config() {
    :
}

action_setup() {
    nds_mode_resolve || true

    if ! nds_cfg_validate_all; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_cfg_validate_all || exit 11
    fi

    nds_cfg_menu_or_skip || exit 12

    local disk_strategy disk_target
    disk_strategy="$(nds_cfg_get "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_cfg_get "DISK_TARGET")"

    nds_preflight_install "$disk_target" || exit 11

    nds_action_confirm_install "$disk_target" "$disk_strategy" || exit 13

    nds_install_ui_section_nixos_install
    nds_install_log "classicInstall: action starting"

    NDS_UI_QUIET=true
    nds_step_exec "Generating access secrets" _install_generate_access_secrets || exit 14
    nds_step_exec "Generating configuration.nix" nds_nixcfg_write_classic || exit 14

    nds_nixos_install || exit 15

    nds_install_finish || exit 16
}
