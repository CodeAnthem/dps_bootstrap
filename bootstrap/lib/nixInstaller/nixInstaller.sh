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
    local disk encryption hostname
    disk=$(nds_config_get "disk" "DISK_TARGET")
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    hostname=$(nds_config_get "network" "HOSTNAME")
    
    nds_nixinstall "$disk" "$encryption" "$hostname"
}

# Manual mode: explicit parameters
# Usage: nds_nixinstall "disk" "encryption" "hostname"
nds_nixinstall() {
    local disk="$1"
    local encryption="${2:-false}"
    local hostname="${3:-nixos}"
    
    log "Starting NixOS installation"
    log "Disk: $disk"
    log "Encryption: $encryption"
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
    
    # Step 4: Generate hardware configuration
    if ! _nixinstall_generate_hardware_config; then
        error "Hardware configuration generation failed"
    fi
    
    success "NixOS disk preparation completed successfully"
    log "Configuration must be written to /mnt/etc/nixos/configuration.nix before running nixos-install"
}
