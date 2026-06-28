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
    PRESET_CONTEXT="installFlake"

    nds_configurator_preset_set_display "installFlake" "Flake install"
    nds_configurator_preset_set_priority "installFlake" 50

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
        display="Host directory inside flake (optional)" \
        input=path \
        default="hosts/x86_64-linux" \
        required=false

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
    console "Install NixOS from a flake configuration."
    console "  • Remote: clone a Git URL onto the target disk"
    console "  • Local: copy a flake already on the live system (USB, second disk, …)"
    console "  • hardware-configuration.nix → host dir when present"
    console "  • nixos-install --flake <path>#<host>"

    nds_askUserToProceed "Ready to configure?" || exit 130

    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12
    _installflake_prepare

    nds_askUserToProceed "Install ${NDS_FLAKE_HOST}? This will erase the target disk." || exit 13

    new_section
    section_header "NixOS installation"
    nds_nixos_install_flake || exit 15

    new_section
    action_show_completion
    nds_askUserToProceed "Reboot now?" && reboot
}
