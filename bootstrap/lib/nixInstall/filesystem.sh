#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Filesystem mounting for NixOS installation
# Feature:       Mount root and boot filesystems
# ==================================================================================================

# =============================================================================
# FILESYSTEM MOUNTING
# =============================================================================

# Mount filesystems for NixOS installation
# Usage: _nixinstall_mount_filesystems "use_encryption"
_nixinstall_mount_filesystems() {
    local use_encryption="${1:-false}"
    
    log "Mounting filesystems"
    
    # Unmount if already mounted
    umount -R /mnt 2>/dev/null || true
    
    # Mount root partition
    if [[ "$use_encryption" == "true" ]]; then
        log "Mounting encrypted root"
        mount /dev/mapper/cryptroot /mnt || return 1
    else
        log "Mounting standard root"
        mount /dev/disk/by-label/nixos /mnt || return 1
    fi
    
    # Mount boot partition
    log "Mounting boot partition"
    mkdir -p /mnt/boot || return 1
    mount /dev/disk/by-label/boot /mnt/boot || return 1
    
    log "Filesystems mounted successfully"
    return 0
}
