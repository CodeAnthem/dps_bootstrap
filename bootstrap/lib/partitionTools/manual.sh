#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2025-11-03
# Description:   Manual (fast) partitioning and mounting using Linux tools
# Feature:       Create GPT, ESP, /boot, (LUKS) root, optional swap/home; mount under /mnt
# ==================================================================================================

# =============================================================================
# MANUAL PARTITIONING (FAST PATH)
# =============================================================================

pt_manual_partition_and_mount() {
    local disk fs_type swap_mib separate_home home_size enc unlock
    disk=$(nds_configurator_config_get_env "DISK_TARGET") || return 1
    fs_type=$(nds_configurator_config_get_env "FS_TYPE" "btrfs")
    swap_mib=$(nds_configurator_config_get_env "SWAP_SIZE_MIB" "0")
    separate_home=$(nds_configurator_config_get_env "SEPARATE_HOME" "false")
    home_size=$(nds_configurator_config_get_env "HOME_SIZE" "20G")
    enc=$(nds_configurator_config_get_env "ENCRYPTION" "true")
    unlock=$(nds_configurator_config_get_env "ENCRYPTION_UNLOCK_MODE" "manual")

    pt_is_disk_ready_to_format "$disk" || return 1

    section_header "Partitioning (fast)"
    info "Creating GPT on $disk"
    parted -s "$disk" mklabel gpt || return 1

    info "Creating ESP (512MiB)"
    parted -s "$disk" mkpart ESP fat32 1MiB 513MiB || return 1
    parted -s "$disk" set 1 boot on || true

    local boot_end="1025MiB"
    info "Creating /boot (512MiB)"
    parted -s "$disk" mkpart BOOT ext4 513MiB "$boot_end" || return 1

    local root_start="$boot_end"
    # Optional swap as partition before root
    local have_swap=false
    if [[ "$swap_mib" != "0" ]]; then
        have_swap=true
        local root_start_mib; root_start_mib=1025
        local root_start_mib_plus_swap
        root_start_mib_plus_swap=$((root_start_mib + swap_mib))
        root_start="${root_start_mib_plus_swap}MiB"
        info "Creating swap (${swap_mib}MiB)"
        parted -s "$disk" mkpart SWAP linux-swap 1025MiB "$root_start" || return 1
    fi

    info "Creating ROOT (rest of disk)"
    parted -s "$disk" mkpart ROOT  "$root_start" 100% || return 1

    # Determine partition names
    local p1 p2 p3 p4; p1=1; p2=2; p3=3; p4=4
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then p1=p1; p2=p2; p3=p3; p4=p4; else p1=1; p2=2; p3=3; p4=4; fi

    # Format ESP
    mkfs.fat -F32 "${disk}${p1}" || return 1
    # Format /boot unencrypted
    mkfs.ext4 -F "${disk}${p2}" || return 1

    local root_dev="${disk}${p3}"
    local mapper=root
    if [[ "$have_swap" == true ]]; then
        # If swap exists, root partition index shifts to p4
        root_dev="${disk}${p4}"
    fi

    if [[ "$enc" == "true" ]]; then
        section_header "Encrypting root"
        # Key/passphrase creation expected to be handled elsewhere; here we do passphrase mode
        cryptsetup luksFormat "$root_dev" || return 1
        cryptsetup open "$root_dev" "$mapper" || return 1
        root_dev="/dev/mapper/$mapper"
    fi

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
        if [[ "$separate_home" == "true" ]]; then
            # separate_home via partition not implemented in fast path; keep subvolume to avoid overcomplexity
            info "Using btrfs @home subvolume (fast path keeps simplicity)"
            mount -o subvol=@home "$root_dev" /mnt/home
        else
            mount -o subvol=@home "$root_dev" /mnt/home
        fi
    else
        mkfs.ext4 -F "$root_dev" || return 1
        mount "$root_dev" /mnt || return 1
        mkdir -p /mnt/{boot,boot/efi}
        if [[ "$separate_home" == "true" ]]; then
            warn "SEPARATE_HOME not implemented for ext4 fast path yet (kept inside /)."
        fi
    fi

    mount "${disk}${p2}" /mnt/boot || return 1
    mount "${disk}${p1}" /mnt/boot/efi || return 1

    if [[ "$have_swap" == true ]]; then
        mkswap "${disk}${p3}" || return 1
        swapon "${disk}${p3}" || true
    fi

    success "Partitioning and mounting (fast) complete"
}
