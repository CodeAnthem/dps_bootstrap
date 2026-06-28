#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from Nix flake action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-06-28
# Description:   Generic nixos-install --flake from the live ISO
# ==================================================================================================

# =============================================================================
# ACTION CONFIGURATION
# =============================================================================
action_config() {
    # Only disk + flake fields apply — timezone/network/etc. live in the user's flake.
    nds_configurator_preset_disable quick
    nds_configurator_preset_disable region
    nds_configurator_preset_disable network
    nds_configurator_preset_disable boot
    nds_configurator_preset_disable security

    nds_configurator_preset_enable installFlake
    nds_configurator_preset_set_display installFlake "Your flake"
    nds_configurator_preset_set_priority installFlake 20

    PRESET_CONTEXT="installFlake"

    nds_configurator_var_declare FLAKE_SOURCE \
        display="Flake source" \
        input=choice \
        default="remote" \
        options="remote|local" \
        required=true

    nds_configurator_var_declare FLAKE_REPO_URL \
        display="Remote flake Git URL" \
        input=url \
        default="" \
        required=false

    nds_configurator_var_declare FLAKE_LOCAL_PATH \
        display="Local flake path (on live system)" \
        input=path \
        default="" \
        required=false

    nds_configurator_var_declare FLAKE_INSTALL_PATH \
        display="Flake path on installed disk" \
        input=path \
        default="/mnt/opt/flake" \
        required=true

    nds_configurator_var_declare FLAKE_HOST \
        display="nixosConfigurations host name" \
        input=hostname \
        required=true

    nds_configurator_var_declare FLAKE_HOST_DIR \
        display="Host directory inside flake" \
        input=path \
        default="hosts/x86_64-linux" \
        required=false

    nds_configurator_var_declare DISK_PREP \
        display="Disk preparation" \
        input=choice \
        default="nds" \
        options="nds|skip" \
        help="nds: NDS partitions and mounts /mnt. skip: you already mounted /mnt (disko/advanced)."

    nds_configurator_var_declare HARDWARE_CONFIG \
        display="Hardware configuration" \
        input=choice \
        default="copy" \
        options="copy|skip" \
        help="copy: generate and place hardware-configuration.nix in host dir. skip: flake handles hardware."

    PRESET_CONTEXT=""
}

_installflake_prepare() {
    local host source
    source=$(nds_configurator_config_get "FLAKE_SOURCE")
    host=$(nds_configurator_config_get "FLAKE_HOST")

    nds_configurator_config_set "HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"
    export NDS_FLAKE_SOURCE="$source"
    export NDS_FLAKE_REPO_URL="$(nds_configurator_config_get "FLAKE_REPO_URL")"
    export NDS_FLAKE_LOCAL_PATH="$(nds_configurator_config_get "FLAKE_LOCAL_PATH")"
    export NDS_FLAKE_INSTALL_PATH="$(nds_configurator_config_get "FLAKE_INSTALL_PATH")"
    export NDS_FLAKE_HOST_DIR="$(nds_configurator_config_get "FLAKE_HOST_DIR")"
    export NDS_DISK_PREP="$(nds_configurator_config_get "DISK_PREP")"
    export NDS_HARDWARE_CONFIG="$(nds_configurator_config_get "HARDWARE_CONFIG")"

    log "Flake target: ${NDS_FLAKE_INSTALL_PATH}#${host} (source: ${source})"
}

action_show_completion() {
    console ""
    console "Installed: ${NDS_FLAKE_HOST:-unknown}"
    console "  Flake on disk: ${NDS_FLAKE_ROOT:-unknown}"
    console ""
    console "Next steps:"
    console "  1. Back up runtime secrets (LUKS key, if encryption was enabled)"
    console "  2. Reboot into the installed system"
    console ""
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================
action_setup() {
    console "Install NixOS from your flake."
    console "  Your flake owns system config (timezone, users, services)."
    console "  NDS handles disk prep, hardware facts, staging the flake, and nixos-install."
    console ""
    console "  See LIMITATIONS.md if your flake uses disko or custom partitioning."

    nds_askUserToProceed "Ready to configure?" || exit 130

    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12
    _installflake_prepare

    local confirm_msg="Install ${NDS_FLAKE_HOST}?"
    if [[ "${NDS_DISK_PREP:-nds}" == "nds" ]]; then
        confirm_msg+=" This will erase and repartition the target disk."
    else
        confirm_msg+=" Disk preparation is skipped — ensure /mnt is correct."
    fi
    nds_askUserToProceed "$confirm_msg" || exit 13

    new_section
    section_header "NixOS installation"
    nds_nixos_install_flake || exit 15

    new_section
    action_show_completion
    nds_askUserToProceed "Reboot now?" && reboot
}
