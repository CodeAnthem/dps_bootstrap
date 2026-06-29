#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action (no flake)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Install NixOS with a generated /etc/nixos configuration (no flake needed)
# ==================================================================================================

action_config() {
    nds_configurator_preset_disable installFlake
    nds_configurator_preset_disable security
}

action_setup() {
    nds_action_overview \
        "Classic NixOS installation (no flake required)" \
        "timezone, locales, keyboard, network, admin user, bootloader, disk" \
        "partition the target disk, generate configuration.nix and hardware-configuration.nix, run nixos-install, reboot"

    nds_askUserContinue_or_exit "Proceed to configuration wizard?" || return $?

    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12

    local disk_strategy confirm_msg disk_target
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"

    nds_preflight_install "$disk_target" || exit 11

    confirm_msg="Install NixOS with generated /etc/nixos config?"
    if [[ "$disk_strategy" == "flake" ]]; then
        confirm_msg+=" Disk strategy is flake — /mnt must already be mounted."
    elif [[ "$disk_strategy" == "disko" ]]; then
        confirm_msg+=" Disko will repartition ${disk_target}."
    else
        confirm_msg+=" This will erase and repartition ${disk_target}."
    fi
    nds_askUserToProceed "$confirm_msg" || exit 13

    step_start "Generating configuration.nix"
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$NDS_RUNTIME_DIR/config/configuration.nix"
    step_complete "Configuration generated"

    new_section
    section_header "NixOS installation"
    nds_install_log "classicInstall: action starting"
    nds_nixos_install || exit 15

    new_section
    console "Installed with a classic /etc/nixos configuration."
    console "  Flakes are enabled — you can migrate to a flake later."
    console ""
    nds_secrets_offer_backup
    nds_askUserToProceed "Reboot now?" && reboot
}
