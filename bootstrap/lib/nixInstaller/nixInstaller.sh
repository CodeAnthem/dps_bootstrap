#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Main NixOS installation orchestration
# Feature:       Orchestrates disk setup, encryption, mounting, and NixOS installation
# ==================================================================================================

# =============================================================================
# NIXOS INSTALLATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
# Usage: nds_nixinstall_auto
nds_nixinstall_auto() {
    local disk encryption hostname remote_unlock
    disk=$(nds_config_get "disk" "DISK_TARGET")
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    hostname=$(nds_config_get "network" "HOSTNAME")
    remote_unlock=$(nds_config_get "disk" "REMOTE_UNLOCK")
    
    nds_nixinstall "$disk" "$encryption" "$hostname" "$remote_unlock"
}

# Manual mode: explicit parameters
# Usage: nds_nixinstall "disk" "encryption" "hostname"
nds_nixinstall() {
    local disk="$1"
    local encryption="${2:-false}"
    local hostname="${3:-nixos}"
    local remote_unlock="${4:-false}"
    
    log "Starting NixOS installation"
    log "Disk: $disk"
    log "Encryption: $encryption"
    log "Remote unlock: $remote_unlock"
    log "Hostname: $hostname"
    
    # Step 1: Setup encryption (if enabled - generates key before partitioning)
    if [[ "$encryption" == "true" ]]; then
        if ! _nixinstall_setup_encryption; then
            error "Encryption setup failed"
        fi
    fi
    
    # Step 2: Partition disk
    if ! _nixinstall_partition_disk "$disk" "$encryption"; then
        error "Disk partitioning failed"
    fi
    
    # Step 3: Mount filesystems
    if ! _nixinstall_mount_filesystems "$encryption"; then
        error "Failed to mount filesystems"
    fi

    # Step 4: Initrd SSH keys for remote unlock (target root filesystem)
    if [[ "$encryption" == "true" && "$remote_unlock" == "true" ]]; then
        if ! _nixinstall_setup_initrd_ssh_keys; then
            error "Initrd SSH host key setup failed"
        fi
    fi
    
    # Step 5: Generate hardware configuration
    if ! _nixinstall_generate_hardware_config; then
        error "Hardware configuration generation failed"
    fi

    # Step 6: machine.nix is written after flake staging in nds_nixos_install_flake
    
    success "NixOS disk preparation completed successfully"
}

# =============================================================================
# COMPLETE INSTALLATION WORKFLOW
# =============================================================================

# Complete NixOS installation including disk prep and nixos-install
# Expects configs to be in $NDS_RUNTIME_DIR/config/
# Usage: nds_nixos_install
nds_nixos_install() {
    # 1. Disk preparation (partition, encrypt, mount, hardware config)
    step_start "Preparing disk and filesystems"
    if ! nds_nixinstall_auto; then
        step_fail "Disk preparation failed"
        return 1
    fi
    step_complete "Disk ready"
    
    # 2. Copy hardware config to runtime directory
    if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
        cp /mnt/etc/nixos/hardware-configuration.nix "$NDS_RUNTIME_DIR/config/"
    fi
    
    # 3. Copy all configs from runtime to /mnt
    step_start "Installing configuration files"
    cp "$NDS_RUNTIME_DIR/config/"*.nix /mnt/etc/nixos/ || {
        step_fail "Failed to copy configuration"
        return 1
    }
    
    # Copy action's predefined config if specified
    if [[ -n "$NDS_ACTION_CONFIG_SOURCE" ]] && [[ -f "$NDS_ACTION_CONFIG_SOURCE" ]]; then
        cp "$NDS_ACTION_CONFIG_SOURCE" /mnt/etc/nixos/"${NDS_ACTION_CONFIG_FILE}" || {
            step_fail "Failed to copy action config"
            return 1
        }
    fi
    step_complete "Configuration installed"
    
    # 4. Run nixos-install
    step_start "Installing NixOS"
    if ! _nixinstall_install_nixos; then
        step_fail "NixOS installation failed"
        return 1
    fi
    step_complete "NixOS installed"
    
    return 0
}

# Complete flake-based installation
# Requires: FLAKE_* config or NDS_FLAKE_* env, configurator hostname
# Usage: nds_nixos_install_flake
nds_nixos_install_flake() {
    local flake_root repo_url install_path hostname host_dir_rel source local_path
    local disk_prep hw_mode encryption disk
    hostname=$(nds_config_get "network" "HOSTNAME")
    source="${NDS_FLAKE_SOURCE:-$(nds_configurator_config_get "FLAKE_SOURCE")}"
    repo_url="${NDS_FLAKE_REPO_URL:-$(nds_configurator_config_get "FLAKE_REPO_URL")}"
    local_path="${NDS_FLAKE_LOCAL_PATH:-$(nds_configurator_config_get "FLAKE_LOCAL_PATH")}"
    install_path="${NDS_FLAKE_INSTALL_PATH:-$(nds_configurator_config_get "FLAKE_INSTALL_PATH")}"
    host_dir_rel="${NDS_FLAKE_HOST_DIR:-$(nds_configurator_config_get "FLAKE_HOST_DIR")}"
    disk_prep="${NDS_DISK_PREP:-$(nds_configurator_config_get "DISK_PREP")}"
    hw_mode="${NDS_HARDWARE_CONFIG:-$(nds_configurator_config_get "HARDWARE_CONFIG")}"
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    disk=$(nds_config_get "disk" "DISK_TARGET")

    if [[ -z "$hostname" ]]; then
        error "HOSTNAME must be set before flake install"
    fi

    if [[ "$disk_prep" == "skip" ]]; then
        step_start "Verifying /mnt (disk prep skipped)"
        if ! mountpoint -q /mnt; then
            step_fail "/mnt is not mounted — required when disk preparation is skip"
            return 1
        fi
        if [[ "$hw_mode" != "skip" ]]; then
            if ! _nixinstall_generate_hardware_config; then
                step_fail "Hardware configuration generation failed"
                return 1
            fi
        fi
        step_complete "Using existing /mnt"
    else
        step_start "Preparing disk and filesystems"
        if ! nds_nixinstall_auto; then
            step_fail "Disk preparation failed"
            return 1
        fi
        step_complete "Disk ready"
    fi

    step_start "Staging flake on target disk"
    case "$source" in
        local)
            if ! _nixinstall_stage_local_flake "$local_path" "$install_path"; then
                step_fail "Local flake staging failed"
                return 1
            fi
            ;;
        remote|*)
            if [[ -z "$repo_url" ]]; then
                error "FLAKE_REPO_URL is required for remote flake source"
            fi
            if ! _nixinstall_ensure_flake_checkout "$repo_url" "$install_path"; then
                step_fail "Flake checkout failed"
                return 1
            fi
            ;;
    esac
    flake_root="$install_path"
    export NDS_FLAKE_ROOT="$flake_root"
    step_complete "Flake at $flake_root"

    step_start "Installing hardware configuration into flake host dir"
    [[ -z "$host_dir_rel" ]] && host_dir_rel="hosts/x86_64-linux"
    local host_dir="${flake_root}/${host_dir_rel}/${hostname}"
    if [[ "$hw_mode" == "skip" ]]; then
        log "Skipping hardware-configuration.nix copy (HARDWARE_CONFIG=skip)"
    else
        mkdir -p "$host_dir"
        if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
            cp /mnt/etc/nixos/hardware-configuration.nix "${host_dir}/hardware-configuration.nix"
            chmod 600 "${host_dir}/hardware-configuration.nix"
        else
            warn "No hardware-configuration.nix generated — host may use eval stub"
        fi
    fi
    step_complete "Hardware config handled"

    if [[ "$encryption" == "true" ]]; then
        step_start "Writing machine facts (LUKS UUID)"
        if ! _nixinstall_write_machine_facts "$disk" "$hostname" "$flake_root" "$encryption" "$host_dir_rel"; then
            step_fail "Failed to write machine.nix host facts"
            return 1
        fi
        step_complete "machine.nix updated"
    fi

    step_start "Installing NixOS from flake"
    if ! _nixinstall_install_nixos_flake "$flake_root" "$hostname"; then
        step_fail "NixOS installation failed"
        return 1
    fi
    step_complete "NixOS installed"

    return 0
}
