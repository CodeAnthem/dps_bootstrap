#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2025-11-03
# Description:   Manual (fast) partitioning and mounting using Linux tools
# Feature:       Create GPT, ESP, /boot, (LUKS) root, optional swap/home; mount under /mnt
# ==================================================================================================

# =============================================================================
# MANUAL PARTITIONING (FAST PATH) - INTERNAL APPLY
# =============================================================================
_nds_partition_manual_create_layout() {
    local disk="$1" swap_mib="$2"
    parted -s "$disk" mklabel gpt || return 1
    parted -s "$disk" mkpart ESP fat32 1MiB 513MiB || return 1
    parted -s "$disk" set 1 boot on || true
    parted -s "$disk" mkpart BOOT ext4 513MiB 1025MiB || return 1
    local root_start="1025MiB"
    if [[ "$swap_mib" != "0" ]]; then
        local root_start_mib_plus_swap=$((1025 + swap_mib))
        parted -s "$disk" mkpart SWAP linux-swap 1025MiB "${root_start_mib_plus_swap}MiB" || return 1
        root_start="${root_start_mib_plus_swap}MiB"
    fi
    parted -s "$disk" mkpart ROOT "$root_start" 100% || return 1
}

_nds_partition_manual_root_device() {
    local disk="$1" swap_mib="$2"
    local idx_root=3
    if [[ "$swap_mib" != "0" ]]; then idx_root=4; fi
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
        echo "${disk}p${idx_root}"
    else
        echo "${disk}${idx_root}"
    fi
}

_nds_partition_manual_encrypt_root() {
    local root_part="$1" unlock="$2"
    local mapper="cryptroot"
    # Tune KDF for broader compatibility on low-memory systems (~64MiB)
    local kdf_opts=(--type luks2 --pbkdf argon2id --pbkdf-memory 65536 --pbkdf-parallel 1 --iter-time 2000)
    # Clean previous mappings and signatures to avoid conflicts
    cryptsetup close "$mapper" >/dev/null 2>&1 || true
    wipefs -a "$root_part" >/dev/null 2>&1 || true
    if command -v blkdiscard >/dev/null 2>&1; then
        blkdiscard -f "$root_part" >/dev/null 2>&1 || true
    fi

    if [[ "$unlock" == "keyfile" ]]; then
        local keyfile="/tmp/luks_key.bin"
        # Create a raw 64-byte keyfile (binary)
        dd if=/dev/urandom of="$keyfile" bs=64 count=1 status=none || return 1
        chmod 600 "$keyfile"
        cryptsetup luksFormat --batch-mode "${kdf_opts[@]}" "$root_part" --key-file "$keyfile" --keyfile-size 64 >/dev/null 2>&1 || return 1
        cryptsetup open "$root_part" "$mapper" --key-file "$keyfile" --keyfile-size 64 >/dev/null 2>&1 || return 1
    else
        cryptsetup luksFormat --batch-mode "${kdf_opts[@]}" "$root_part" >/dev/null 2>&1 || return 1
        cryptsetup open "$root_part" "$mapper" >/dev/null 2>&1 || return 1
    fi
    _nds_partition_wait_mapper "$mapper" || return 1
    if command -v cryptsetup >/dev/null 2>&1; then
        cryptsetup status "$mapper" >/dev/null 2>&1 || true
    fi
    echo "/dev/mapper/$mapper"
}

_nds_partition_wait_mapper() {
    local name="$1"; local timeout=20; local i
    if command -v udevadm >/dev/null 2>&1; then
        udevadm settle || true
    fi
    for ((i=0; i<timeout; i++)); do
        [[ -e "/dev/mapper/$name" ]] && return 0
        sleep 1
    done
    error "Timeout waiting for /dev/mapper/$name"
    return 1
}

_nds_partition_manual_format_and_mount() {
    local disk="$1" root_dev="$2" fs_type="$3" separate_home="$4"
    local p1 p2
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then p1="${disk}p1"; p2="${disk}p2"; else p1="${disk}1"; p2="${disk}2"; fi
    mkfs.fat -F32 "$p1" || return 1
    mkfs.ext4 -F "$p2" || return 1

    if [[ "$fs_type" == "btrfs" ]]; then
        mkfs.btrfs -f "$root_dev" || return 1
        mount "$root_dev" /mnt || return 1
        btrfs subvolume create /mnt/@ || true
        btrfs subvolume create /mnt/@nix || true
        btrfs subvolume create /mnt/@var || true
        btrfs subvolume create /mnt/@home || true
        umount /mnt
        mount -o subvol=@ "$root_dev" /mnt || return 1
        mkdir -p /mnt/{nix,var,home,boot,boot/efi}
        mount -o subvol=@nix "$root_dev" /mnt/nix
        mount -o subvol=@var "$root_dev" /mnt/var
        mount -o subvol=@home "$root_dev" /mnt/home
    else
        mkfs.ext4 -F "$root_dev" || return 1
        mount "$root_dev" /mnt || return 1
        mkdir -p /mnt/{boot,boot/efi,home}
        # Note: SEPARATE_HOME as separate partition not implemented in fast path.
    fi

    mount "$p2" /mnt/boot || return 1
    mount "$p1" /mnt/boot/efi || return 1
}

_nds_partition_manual_setup_swap() {
    local disk="$1" swap_mib="$2"
    [[ "$swap_mib" == "0" ]] && return 0
    local p3
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then p3="${disk}p3"; else p3="${disk}3"; fi
    mkswap "$p3" || return 1
    swapon "$p3" || true
}
