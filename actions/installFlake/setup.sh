#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-07-01
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

action_config() {
    nds_configurator_preset_disable quick
    nds_configurator_preset_disable region
    nds_configurator_preset_disable network
    nds_configurator_preset_disable boot
    nds_configurator_preset_disable security
    nds_configurator_preset_disable platform
    nds_configurator_preset_enable installFlake
    nds_configurator_preset_set_display installFlake "Your flake"
    nds_configurator_preset_set_priority installFlake 20
}

action_preview() {
    nds_ui_h "Install NixOS from your flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "flake source and URL or path, host name, host directory"
    nds_ui_i "hardware placement and disk"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "partition the target disk (or defer to your flake)"
    nds_ui_i "generate hardware-configuration.nix and stage the flake"
    nds_ui_i "run nixos-install --flake"
    nds_ui_i "offer an install backup zip, then reboot"
    nds_ui_b ""
}

action_setup() {
    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12
    nds_flake_prepare
    nds_flake_detect_disko

    local disk_strategy disk_target repo_url
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"
    repo_url="$(nds_configurator_config_get "FLAKE_REPO_URL")"

    nds_preflight_install "$disk_target" "$repo_url" || exit 11

    nds_action_confirm_install "$disk_target" "$disk_strategy" || exit 13

    section_header "NixOS installation"
    nds_install_log "installFlake: action starting"
    nds_nixos_install_flake || exit 15

    nds_install_finish || exit 16
}
