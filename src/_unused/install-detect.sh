#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-04 | Modified: 2025-11-04
# Description:   Disk state detection helpers (no prompts)
# Feature:       Determine if a disk is wiped, empty, has filesystems, or is in use
# ==================================================================================================

# ----------------------------------------------------------------------------------
# DETECTION HELPERS (INTERNAL)
# ----------------------------------------------------------------------------------

# _install_partition_disk_has_label
# - Returns 0 if disk has a partition table label (e.g., GPT/MBR), else 1
_install_partition_disk_has_label() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    local out; out=$(lsblk -no PTTYPE "$disk" 2>/dev/null || true)
    [[ -n "$out" ]]
}

# _install_partition_disk_has_partitions
# - Returns 0 if disk has child partitions, else 1
_install_partition_disk_has_partitions() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    lsblk -no NAME "$disk" 2>/dev/null | tail -n +2 | grep -q .
}

# _install_partition_partitions_have_filesystems
# - Returns 0 if any partition has a recognizable filesystem (blkid or lsblk FSTYPE)
_install_partition_partitions_have_filesystems() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # blkid detection first
    if blkid "$disk"* 2>/dev/null | grep -qE 'TYPE="[^"]+"'; then
        return 0
    fi
    # fallback to lsblk FSTYPE
    lsblk -no FSTYPE "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

# _install_partition_in_use
# - Returns 0 if any partition is mounted/in use, else 1
_install_partition_in_use() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    lsblk -no MOUNTPOINT "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

# _install_partition_has_known_signatures
# - Returns 0 if LVM PV, mdraid, or other metadata signatures are detected, else 1
_install_partition_has_known_signatures() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # LVM PV signature
    if command -v pvs >/dev/null 2>&1 && pvs --noheadings "$disk"* 2>/dev/null | grep -q .; then
        return 0
    fi
    # mdadm RAID signature
    if command -v mdadm >/dev/null 2>&1 && mdadm --examine --brief "$disk"* 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# _install_partition_summarize_disk
# - Prints a short summary table of disk/partitions
_install_partition_summarize_disk() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk" 2>/dev/null
}

# _install_partition_check_disk_state
# - Echoes one of: wiped | empty_parts | has_fs | in_use
_install_partition_check_disk_state() {
    local disk="$1"; [[ -n "$disk" ]] || { echo "wiped"; return 1; }

    if _install_partition_in_use "$disk"; then
        echo "in_use"; return 0
    fi
    if _install_partition_partitions_have_filesystems "$disk" || _install_partition_has_known_signatures "$disk"; then
        echo "has_fs"; return 0
    fi
    if _install_partition_disk_has_label "$disk" || _install_partition_disk_has_partitions "$disk"; then
        echo "empty_parts"; return 0
    fi
    echo "wiped"; return 0
}
