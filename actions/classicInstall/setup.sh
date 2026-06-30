#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action (no flake)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
# Description:   Install NixOS with a generated /etc/nixos configuration (no flake needed)
# ==================================================================================================

action_config() {
    nds_configurator_preset_disable installFlake
    nds_configurator_preset_disable security
    nds_configurator_preset_disable remoteAction
}

_classicinstall_write_config() {
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$NDS_RUNTIME_DIR/config/configuration.nix"
}

action_preview() {
    nds_ui_h "Classic NixOS installation (no flake required)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "timezone, locales, keyboard, network, admin user"
    nds_ui_i "bootloader and disk"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "partition the target disk"
    nds_ui_i "generate configuration.nix and hardware-configuration.nix"
    nds_ui_i "run nixos-install"
    nds_ui_i "offer an install backup zip, then reboot"
    nds_ui_b ""
}

action_setup() {
    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12

    local disk_strategy disk_target
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"

    nds_preflight_install "$disk_target" || exit 11

    nds_action_confirm_install "$disk_target" "$disk_strategy" || exit 13

    section_header "NixOS installation"
    nds_install_log "classicInstall: action starting"

    NDS_UI_QUIET=true
    nds_step_exec "Generating configuration.nix" _classicinstall_write_config || exit 14

    nds_nixos_install || exit 15

    nds_install_finish || exit 16
}
