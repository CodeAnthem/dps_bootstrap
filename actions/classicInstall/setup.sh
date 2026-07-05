#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action (no flake)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-05
# Description:   Install NixOS with a generated /etc/nixos configuration (no flake needed)
# ==================================================================================================

action_presets() {
    printf '%s\n' quick region network boot access disk encryption platform
}

action_config() {
    :
}

action_preview() {
    nds_ui_h "Classic NixOS installation (no flake required)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "timezone, locales, keyboard, network, admin user"
    nds_ui_i "bootloader and disk"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "1. partition the target disk (and set up LUKS2 if encryption is enabled)"
    nds_ui_i "2. generate configuration.nix and hardware-configuration.nix"
    nds_ui_i "3. run nixos-install (Nix downloads and builds packages)"
    nds_ui_i "4. offer an install backup zip, then reboot"
    nds_ui_b ""
}

action_setup() {
    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu_or_skip || exit 12

    local disk_strategy disk_target
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"

    nds_preflight_install "$disk_target" || exit 11

    nds_action_confirm_install "$disk_target" "$disk_strategy" || exit 13

    section_header "NixOS installation"
    nds_install_log "classicInstall: action starting"

    NDS_UI_QUIET=true
    nds_step_exec "Generating access secrets" _nixinstall_generate_access_secrets || exit 14
    nds_step_exec "Generating configuration.nix" nds_nixcfg_write_classic || exit 14

    nds_nixos_install || exit 15

    nds_install_finish || exit 16
}
