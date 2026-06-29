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
    local disk_strategy
    disk_strategy=$(nds_config_get "disk" "DISK_STRATEGY")
    disk_strategy="${disk_strategy:-nds}"
    
    log "Starting NixOS installation"
    log "Disk: $disk"
    log "Disk strategy: $disk_strategy"
    log "Encryption: $encryption"
    log "Remote unlock: $remote_unlock"
    log "Hostname: $hostname"
    
    if [[ "$disk_strategy" == "flake" ]]; then
        warn "disk strategy 'flake' skips NDS partitioning — use only from flake install with /mnt ready"
        return 0
    fi

    if [[ "$disk_strategy" == "disko" ]]; then
        if ! nds_partition_run_disko_from_config; then
            error "Disko partitioning failed"
        fi
    else
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
    nds_install_log "classicInstall: nds_nixos_install starting"
    nds_preflight_install "$(nds_config_get "disk" "DISK_TARGET")" || return 1

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
    nds_install_log "classicInstall: completed"

    return 0
}

# Complete flake-based installation
# Requires: FLAKE_* config or NDS_FLAKE_* env, configurator hostname
# Usage: nds_nixos_install_flake
nds_nixos_install_flake() {
    local flake_root repo_url install_path hostname host_dir_rel source local_path
    local disk_prep hw_mode encryption disk disk_strategy
    hostname=$(nds_config_get "network" "HOSTNAME")
    source="${NDS_FLAKE_SOURCE:-$(nds_configurator_config_get "FLAKE_SOURCE")}"
    repo_url="${NDS_FLAKE_REPO_URL:-$(nds_configurator_config_get "FLAKE_REPO_URL")}"
    local_path="${NDS_FLAKE_LOCAL_PATH:-$(nds_configurator_config_get "FLAKE_LOCAL_PATH")}"
    install_path="${NDS_FLAKE_INSTALL_PATH:-$(nds_configurator_config_get "FLAKE_INSTALL_PATH")}"
    host_dir_rel="${NDS_FLAKE_HOST_DIR:-$(nds_configurator_config_get "FLAKE_HOST_DIR")}"
    disk_strategy="${NDS_DISK_STRATEGY:-$(nds_config_get "disk" "DISK_STRATEGY")}"
    disk_strategy="${disk_strategy:-nds}"
    hw_mode="${NDS_HARDWARE_PLACEMENT:-$(nds_configurator_config_get "HARDWARE_PLACEMENT")}"
    hw_mode="${hw_mode:-host-dir}"
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    disk=$(nds_config_get "disk" "DISK_TARGET")

    if [[ -z "$hostname" ]]; then
        error "HOSTNAME must be set before flake install"
    fi

    nds_install_log "installFlake: host=${hostname} strategy=${disk_strategy} hw=${hw_mode}"
    nds_preflight_install "$disk" "$repo_url" || return 1

    if [[ "$disk_strategy" == "flake" ]]; then
        step_start "Verifying /mnt (flake-owned disk)"
        if ! mountpoint -q /mnt; then
            step_fail "/mnt is not mounted — required when disk strategy is flake"
            error "Mount /mnt per your flake docs, or use disko from the flake before install"
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

    step_start "Hardware configuration"
    [[ -z "$host_dir_rel" ]] && host_dir_rel="hosts/x86_64-linux"
    local host_dir="${flake_root}/${host_dir_rel}/${hostname}"
    case "$hw_mode" in
        skip)
            log "Skipping hardware-configuration.nix (HARDWARE_PLACEMENT=skip)"
            ;;
        etc-nixos)
            log "Keeping hardware-configuration.nix in /etc/nixos only"
            mkdir -p /mnt/etc/nixos
            ;;
        host-dir|*)
            mkdir -p "$host_dir"
            local hw_dest="${host_dir}/hardware-configuration.nix"
            local skip_hw_copy=false
            if [[ -f "$hw_dest" ]]; then
                warn "hardware-configuration.nix already exists: $hw_dest"
                if [[ "${NDS_AUTO_CONFIRM:-false}" != "true" ]]; then
                    if ! nds_askUserToProceed "Overwrite existing hardware-configuration.nix?"; then
                        log "Keeping existing hardware-configuration.nix"
                        skip_hw_copy=true
                    fi
                fi
            fi
            if [[ "$skip_hw_copy" != "true" ]]; then
                if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
                    cp /mnt/etc/nixos/hardware-configuration.nix "$hw_dest"
                    chmod 600 "$hw_dest"
                else
                    warn "No hardware-configuration.nix generated — host may use eval stub"
                fi
            fi
            ;;
    esac
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
    if ! _nixinstall_install_nixos_flake "$flake_root" "$hostname" "$hw_mode"; then
        step_fail "NixOS installation failed"
        return 1
    fi
    step_complete "NixOS installed"
    nds_install_log "installFlake: completed ${flake_root}#${hostname}"

    return 0
}
