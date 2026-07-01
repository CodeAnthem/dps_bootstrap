#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-06-30
# Description:   Disk partitioning for NixOS installation
# Feature:       GPT partitioning, boot and root partition creation
# ==================================================================================================

# =============================================================================
# DISK PARTITIONING
# =============================================================================

# Return partition device path for a disk index (handles nvme/mmcblk).
_nixinstall_disk_part() {
    local disk="$1"
    local index="$2"
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
        echo "${disk}p${index}"
    else
        echo "${disk}${index}"
    fi
}

# Partition disk for NixOS installation
# Usage: _nixinstall_partition_disk "disk" "use_encryption"
_nixinstall_partition_disk() {
    local disk="$1"
    local use_encryption="${2:-false}"
    local uefi_mode boot_idx root_idx

    uefi_mode=$(nds_config_get "boot" "BOOT_UEFI_MODE")
    uefi_mode="${uefi_mode:-true}"

    # Validate disk exists
    if [[ ! -b "$disk" ]]; then
        error "Target disk does not exist: $disk"
    fi

    log "Partitioning disk: $disk (firmware: $([[ "$uefi_mode" == "true" ]] && echo UEFI || echo BIOS))"

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

    if [[ "$uefi_mode" == "true" ]]; then
        # UEFI: ESP + root
        parted "$disk" --script -- mkpart ESP fat32 1MiB 512MiB || return 1
        parted "$disk" --script -- set 1 esp on || return 1
        parted "$disk" --script -- mkpart primary 512MiB 100% || return 1
        boot_idx=1
        root_idx=2
    else
        # BIOS + GPT: bios_grub (GRUB core) + /boot + root
        parted "$disk" --script -- mkpart bios_grub 1MiB 3MiB || return 1
        parted "$disk" --script -- set 1 bios_grub on || return 1
        parted "$disk" --script -- mkpart boot fat32 3MiB 515MiB || return 1
        parted "$disk" --script -- mkpart primary 515MiB 100% || return 1
        boot_idx=2
        root_idx=3
    fi

    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$disk" || true

    local boot_part root_part
    boot_part=$(_nixinstall_disk_part "$disk" "$boot_idx")
    root_part=$(_nixinstall_disk_part "$disk" "$root_idx")

    # Format boot partition
    log "Formatting boot partition"
    mkfs.fat -F 32 -n boot "$boot_part" || return 1

    # Setup root partition (encrypted or standard)
    if [[ "$use_encryption" == "true" ]]; then
        log "Setting up encrypted root partition"
        _nixinstall_format_luks "$root_part" || return 1
    else
        log "Setting up standard root partition"
        mkfs.ext4 -L nixos "$root_part" || return 1
    fi
    
    return 0
}
