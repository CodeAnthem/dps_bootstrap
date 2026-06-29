#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from Nix flake action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-06-29
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

action_config() {
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

    nds_configurator_var_declare HARDWARE_PLACEMENT \
        display="Hardware configuration" \
        input=choice \
        default="host-dir" \
        options="host-dir|etc-nixos|skip" \
        help="host-dir: copy into flake host folder (gitignored). etc-nixos: keep in /etc/nixos + override-input. skip: flake handles hardware."

    PRESET_CONTEXT=""
}

_installflake_prepare() {
    local host source repo_url local_path install_path host_dir hw_placement disk_strategy
    source=$(nds_configurator_config_get "FLAKE_SOURCE")
    host=$(nds_configurator_config_get "FLAKE_HOST")
    repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")
    local_path=$(nds_configurator_config_get "FLAKE_LOCAL_PATH")
    install_path=$(nds_configurator_config_get "FLAKE_INSTALL_PATH")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    hw_placement=$(nds_configurator_config_get "HARDWARE_PLACEMENT")
    disk_strategy=$(nds_config_get "disk" "DISK_STRATEGY")

    nds_configurator_config_set "HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"
    export NDS_FLAKE_SOURCE="$source"
    export NDS_FLAKE_REPO_URL="$repo_url"
    export NDS_FLAKE_LOCAL_PATH="$local_path"
    export NDS_FLAKE_INSTALL_PATH="$install_path"
    export NDS_FLAKE_HOST_DIR="$host_dir"
    export NDS_HARDWARE_PLACEMENT="$hw_placement"
    export NDS_DISK_STRATEGY="$disk_strategy"

    log "Flake target: ${NDS_FLAKE_INSTALL_PATH}#${host} (source: ${source})"
}

_installflake_detect_disko() {
    local source host host_dir local_path repo_url probe_root
    source=$(nds_configurator_config_get "FLAKE_SOURCE")
    host=$(nds_configurator_config_get "FLAKE_HOST")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    host_dir="${host_dir:-hosts/x86_64-linux}"

    case "$source" in
        local)
            local_path=$(nds_configurator_config_get "FLAKE_LOCAL_PATH")
            [[ -d "$local_path" ]] && nds_preflight_apply_disko_strategy "$local_path" "$host" "$host_dir"
            ;;
        remote)
            repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")
            [[ -z "$repo_url" ]] && return 0
            probe_root=$(nds_preflight_probe_flake "$repo_url") || return 0
            nds_preflight_apply_disko_strategy "$probe_root" "$host" "$host_dir"
            ;;
    esac
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

action_setup() {
    nds_action_overview \
        "Install NixOS from your flake" \
        "flake source and URL/path, host name, host directory, hardware placement, disk" \
        "partition the target disk (or defer to your flake), generate hardware-configuration.nix, stage the flake, run nixos-install --flake, reboot"

    nds_askUserContinue_or_exit "Proceed to configuration wizard?" || return $?

    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12
    _installflake_prepare
    _installflake_detect_disko

    local disk_strategy confirm_msg disk_target repo_url
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"
    repo_url="$(nds_configurator_config_get "FLAKE_REPO_URL")"

    nds_preflight_install "$disk_target" "$repo_url" || exit 11

    confirm_msg="Install ${NDS_FLAKE_HOST}?"
    if [[ "$disk_strategy" == "flake" ]]; then
        confirm_msg+=" Disk strategy is flake — NDS will not partition; /mnt must be ready."
    elif [[ "$disk_strategy" == "disko" ]]; then
        confirm_msg+=" Disko will repartition ${disk_target}."
    else
        confirm_msg+=" This will erase and repartition ${disk_target}."
    fi
    nds_askUserToProceed "$confirm_msg" || exit 13

    new_section
    section_header "NixOS installation"
    nds_install_log "installFlake: action starting"
    nds_nixos_install_flake || exit 15

    new_section
    action_show_completion
    nds_secrets_offer_backup
    nds_askUserToProceed "Reboot now?" && reboot
}
