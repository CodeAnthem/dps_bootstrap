#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Disk partitioning for NixOS installation
# Feature:       GPT partitioning, boot and root partition creation
# ==================================================================================================

# ----------------------------------------------------------------------------------
# DISK PARTITIONING
# ----------------------------------------------------------------------------------

# Partition disk for NixOS installation
# Usage: _nixinstall_partition_disk "disk" "use_encryption"
_nixinstall_partition_disk() {
    local disk="$1"
    local use_encryption="${2:-false}"
    
    # Validate disk exists
    if [[ ! -b "$disk" ]]; then
        error "Target disk does not exist: $disk"
    fi
    
    log "Partitioning disk: $disk"
    
    # Cleanup: unmount any existing partitions and close LUKS devices
    log "Cleaning up existing partitions"
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
    
    # Wipe any existing filesystem signatures
    for part in "${disk}"*; do
        [[ -b "$part" ]] && wipefs -a "$part" 2>/dev/null || true
    done
    
    # Create GPT partition table
    parted "$disk" --script -- mklabel gpt || return 1
    
    # Create EFI boot partition (512MB)
    parted "$disk" --script -- mkpart ESP fat32 1MiB 512MiB || return 1
    parted "$disk" --script -- set 1 esp on || return 1
    
    # Create root partition (remaining space)
    parted "$disk" --script -- mkpart primary 512MiB 100% || return 1
    
    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$disk" || true
    
    # Format boot partition
    log "Formatting boot partition"
    mkfs.fat -F 32 -n boot "${disk}1" || return 1
    
    # Setup root partition (encrypted or standard)
    if [[ "$use_encryption" == "true" ]]; then
        log "Setting up encrypted root partition"
        _nixinstall_setup_luks_partition "${disk}2" || return 1
    else
        log "Setting up standard root partition"
        mkfs.ext4 -L nixos "${disk}2" || return 1
    fi
    
    return 0
}
