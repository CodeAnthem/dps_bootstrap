#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-07-04
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

action_config() {
    nds_configurator_preset_disable quick
    nds_configurator_preset_disable region
    nds_configurator_preset_disable network
    nds_configurator_preset_disable security
    nds_configurator_preset_disable platform
    nds_configurator_preset_enable installFlake
    nds_configurator_preset_set_display installFlake "Your flake"
    nds_configurator_preset_set_priority installFlake 20
    nds_configurator_preset_set_priority boot 21
    nds_configurator_preset_set_priority encryption 22
}

action_preview() {
    nds_ui_h "Install NixOS from your flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "install mode (local live ISO or remote nixos-anywhere)"
    nds_ui_i "flake location (git URL or path, auto-detected), host name, host directory"
    nds_ui_i "bootloader (UEFI mode + GRUB / systemd-boot / rEFInd), disk (local mode)"
    nds_ui_b ""
    nds_ui_b "For a private repo, NDS verifies SSH access to the root flake and all"
    nds_ui_b "locked inputs before partitioning, then helps set up a deploy key."
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

    nds_configurator_menu || exit 12
    nds_flake_prepare
    nds_git_ensure_access "$(nds_configurator_config_get FLAKE_REPO_URL)" || exit 11
    nds_flake_detect_disko

    local host probe_dir local_path
    host="$(nds_configurator_config_get FLAKE_HOST)"
    local_path="$(nds_configurator_config_get FLAKE_LOCAL_PATH)"
    if [[ -n "$local_path" && -d "$local_path" ]]; then
        probe_dir="$local_path"
    elif [[ -d "${NDS_RUNTIME_DIR}/flake_probe" ]]; then
        probe_dir="${NDS_RUNTIME_DIR}/flake_probe"
    fi
    if [[ -n "${probe_dir:-}" ]]; then
        section_header "Verifying flake access"
        nds_preflight_flake_buildable "$probe_dir" "$host" || exit 11
    fi

    local disk_strategy disk_target repo_url install_mode target_ip
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"
    repo_url="$(nds_configurator_config_get "FLAKE_REPO_URL")"
    install_mode="$(nds_configurator_config_get "INSTALL_MODE")"
    install_mode="${install_mode:-local}"
    target_ip="$(nds_configurator_config_get "REMOTE_TARGET_IP")"

    if [[ "$install_mode" == "remote" ]]; then
        nds_preflight_remote_install "$target_ip" "$repo_url" || exit 11
        nds_action_confirm_remote_install "$target_ip" || exit 13
    else
        nds_preflight_install "$disk_target" "$repo_url" || exit 11
        nds_action_confirm_install "$disk_target" "$disk_strategy" || exit 13
    fi

    section_header "NixOS installation"
    nds_install_log "installFlake: action starting (mode=${install_mode})"
    nds_nixos_install_flake || { nds_git_access_cleanup; exit 15; }
    nds_git_access_cleanup

    if [[ "$install_mode" == "remote" ]]; then
        nds_install_remote_finish || exit 16
    else
        nds_install_finish || exit 16
    fi
}
