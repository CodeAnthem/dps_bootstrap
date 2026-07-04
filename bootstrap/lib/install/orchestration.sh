#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-04
# Description:   Main NixOS installation orchestration
# Feature:       Orchestrates disk setup, encryption, mounting, and NixOS installation
# ==================================================================================================

# =============================================================================
# NIXOS INSTALLATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
# Usage: nds_nixinstall_auto [skip_hardware]
# - skip_hardware: <Bool> When "true", skip hardware/facter generation (flake install
#   generates into the host dir after the flake is staged)
nds_nixinstall_auto() {
    local skip_hardware="${1:-false}"
    local disk encryption hostname remote_unlock
    disk=$(nds_config_get "disk" "DISK_TARGET")
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    hostname=$(nds_config_get "network" "NETWORK_HOSTNAME")
    remote_unlock=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_UNLOCK")
    local disk_strategy
    disk_strategy=$(nds_config_get "disk" "DISK_STRATEGY")
    disk_strategy="${disk_strategy:-nds}"

    log "Starting NixOS installation"
    log "Disk: $disk | strategy: $disk_strategy | encryption: $encryption | host: $hostname"

    if [[ "$disk_strategy" == "flake" ]]; then
        warn "disk strategy 'flake' skips NDS partitioning — use only from flake install with /mnt ready"
        return 0
    fi

    if [[ "$disk_strategy" == "disko" ]]; then
        nds_step_exec "Running disko" nds_partition_run_disko_from_config || return 1
    else
        if [[ "$encryption" == "true" ]]; then
            nds_step_exec "Generating encryption secrets" _nixinstall_generate_encryption_secrets || return 1
        fi
        nds_step_exec "Partitioning disk" _nixinstall_partition_disk "$disk" "$encryption" || return 1
        nds_step_exec "Mounting filesystems" _nixinstall_mount_filesystems "$encryption" || return 1
    fi

    if [[ "$encryption" == "true" && "$remote_unlock" == "true" ]]; then
        nds_step_exec "Setting up initrd SSH keys" _nixinstall_setup_initrd_ssh_keys || return 1
    fi

    if [[ "$skip_hardware" != "true" ]]; then
        nds_step_exec "Generating hardware configuration" _nixinstall_generate_hardware_config || return 1
    fi
    log "NixOS disk preparation completed successfully"
    return 0
}

# =============================================================================
# COMPLETE INSTALLATION WORKFLOW
# =============================================================================

# Complete NixOS installation including disk prep and nixos-install
# Expects configs to be in $NDS_RUNTIME_DIR/config/
# Usage: nds_nixos_install
nds_nixos_install() {
    nds_install_log "classicInstall: nds_nixos_install starting"
    nds_preflight_install "$(nds_config_get "disk" "DISK_TARGET")" || return 1

    NDS_UI_QUIET=true

    if ! nds_nixinstall_auto; then
        return 1
    fi

    if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
        cp /mnt/etc/nixos/hardware-configuration.nix "$NDS_RUNTIME_DIR/config/"
    elif [[ -f /mnt/etc/nixos/facter.json ]]; then
        cp /mnt/etc/nixos/facter.json "$NDS_RUNTIME_DIR/config/"
    fi

    nds_step_exec "Installing configuration files" _nixinstall_install_configs || return 1
    nds_step_exec "Installing NixOS" _nixinstall_install_nixos || return 1

    local disk
    disk=$(nds_config_get "disk" "DISK_TARGET")
    nds_step_exec "Registering EFI boot entry" _nixinstall_register_efi_entry "$disk" || true

    nds_install_log "classicInstall: completed"
    return 0
}

# Complete flake-based installation
# Requires: FLAKE_* config or NDS_FLAKE_* env, configurator hostname
# Usage: nds_nixos_install_flake
nds_nixos_install_flake() {
    local flake_root repo_url install_path hostname host_dir_rel source local_path
    local disk_prep hw_mode encryption disk disk_strategy install_mode target_ip
    hostname=$(nds_config_get "network" "NETWORK_HOSTNAME")
    source="${NDS_FLAKE_SOURCE:-$(nds_configurator_config_get "FLAKE_SOURCE")}"
    repo_url="${NDS_FLAKE_REPO_URL:-$(nds_configurator_config_get "FLAKE_REPO_URL")}"
    local_path="${NDS_FLAKE_LOCAL_PATH:-$(nds_configurator_config_get "FLAKE_LOCAL_PATH")}"
    install_path="${NDS_FLAKE_INSTALL_PATH:-$(nds_configurator_config_get "FLAKE_INSTALL_PATH")}"
    host_dir_rel="${NDS_FLAKE_HOST_DIR:-$(nds_configurator_config_get "FLAKE_HOST_DIR")}"
    disk_strategy="${NDS_DISK_STRATEGY:-$(nds_config_get "disk" "DISK_STRATEGY")}"
    disk_strategy="${disk_strategy:-nds}"
    hw_mode="${NDS_HARDWARE_PLACEMENT:-$(nds_configurator_config_get "FLAKE_HARDWARE_PLACEMENT")}"
    hw_mode="${hw_mode:-host-dir}"
    install_mode="${NDS_INSTALL_MODE:-$(nds_configurator_config_get "INSTALL_MODE")}"
    install_mode="${install_mode:-local}"
    target_ip="${NDS_REMOTE_TARGET_IP:-$(nds_configurator_config_get "REMOTE_TARGET_IP")}"
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    disk=$(nds_config_get "disk" "DISK_TARGET")

    if [[ -z "$hostname" ]]; then
        error "NETWORK_HOSTNAME must be set before flake install"
    fi

    if [[ "$install_mode" == "remote" ]]; then
        if [[ -z "$target_ip" ]]; then
            error "REMOTE_TARGET_IP is required when INSTALL_MODE=remote"
        fi

        nds_install_log "installFlake: remote host=${hostname} target=${target_ip}"
        NDS_UI_QUIET=true

        if ! flake_root=$(_nixinstall_resolve_flake_root "$source" "$local_path" "$repo_url"); then
            return 1
        fi
        export NDS_FLAKE_ROOT="$flake_root"

        if [[ "$encryption" == "true" ]]; then
            nds_step_exec "Generating encryption secrets" _nixinstall_generate_encryption_secrets || return 1
        fi

        nds_step_exec "Installing via nixos-anywhere" \
            _nixinstall_via_nixos_anywhere "$flake_root" "$hostname" "$target_ip" || return 1

        nds_install_log "installFlake: remote completed ${flake_root}#${hostname}"
        return 0
    fi

    nds_install_log "installFlake: host=${hostname} strategy=${disk_strategy} hw=${hw_mode}"
    nds_preflight_install "$disk" "$repo_url" || return 1

    NDS_UI_QUIET=true

    if [[ "$disk_strategy" == "flake" ]]; then
        nds_step_exec "Verifying /mnt (flake-owned disk)" bash -c '
            mountpoint -q /mnt
        ' || {
            error "/mnt is not mounted — required when disk strategy is flake"
            return 1
        }
    else
        if ! nds_nixinstall_auto true; then
            return 1
        fi
    fi

    case "$source" in
        local)
            nds_step_exec "Staging flake on target disk" \
                _nixinstall_stage_local_flake "$local_path" "$install_path" || return 1
            ;;
        remote|*)
            if [[ -z "$repo_url" ]]; then
                error "FLAKE_REPO_URL is required for remote flake source"
            fi
            nds_step_exec "Staging flake on target disk" \
                _nixinstall_ensure_flake_checkout "$repo_url" "$install_path" || return 1
            ;;
    esac
    flake_root="$install_path"
    export NDS_FLAKE_ROOT="$flake_root"

    [[ -z "$host_dir_rel" ]] && host_dir_rel="hosts/x86_64-linux"
    local host_dir="${flake_root}/${host_dir_rel}/${hostname}"

    if [[ "$hw_mode" != "skip" ]]; then
        nds_step_exec "Generating hardware facts for flake host" \
            _nixinstall_place_hardware_artifact "$host_dir" "$hw_mode" true || return 1
    else
        log "Skipping hardware artifact (FLAKE_HARDWARE_PLACEMENT=skip)"
    fi

    nds_step_exec "Writing boot module from preset" \
        nds_nixcfg_write_boot_module "${host_dir}/nds-boot.nix" || return 1
    nds_install_log "boot: wrote ${host_dir}/nds-boot.nix from boot preset"

    if [[ "$encryption" == "true" ]]; then
        nds_step_exec "Writing machine facts (LUKS UUID)" \
            _nixinstall_write_machine_facts "$disk" "$hostname" "$flake_root" "$encryption" "$host_dir_rel" || return 1
    fi

    nds_step_exec "Installing NixOS from flake" \
        _nixinstall_install_nixos_flake "$flake_root" "$hostname" "$hw_mode" || return 1

    nds_step_exec "Enrolling sops age key" \
        _nds_enroll_sops_key "$flake_root" "$hostname" "/mnt" || true

    nds_step_exec "Registering EFI boot entry" \
        _nixinstall_register_efi_entry "$disk" || true

    nds_install_log "installFlake: completed ${flake_root}#${hostname}"
    return 0
}
