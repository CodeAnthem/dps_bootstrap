#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-01
# Description:   Bootloader registration (EFI NVRAM entry)
# Feature:       No keyfile is placed on the target — LUKS key (if used) lives on a USB stick
# ==================================================================================================

# Description: Register the NixOS EFI boot entry in firmware NVRAM.
# nixos-install runs bootctl in a chroot where efivars is not writable, so the
# bootloader files are copied but no NVRAM entry is created — some firmware
# (e.g. VMware) then shows "no OS found". This writes the entry from the host.
# Arguments:
# - disk: <String> Target block device (ESP is partition 1)
_nixinstall_register_efi_entry() {
    local disk="$1"
    local uefi

    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE")
    [[ "$uefi" == "true" ]] || return 0

    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        warn "Live system is not booted in UEFI mode — EFI NVRAM entry not written."
        warn "Boot the NixOS ISO in UEFI mode, or pick a BIOS bootloader (GRUB)."
        return 0
    fi

    if ! command -v efibootmgr &>/dev/null; then
        warn "efibootmgr not available — add the EFI boot entry manually in firmware."
        warn "Loader: \\EFI\\systemd\\systemd-bootx64.efi on ${disk}1"
        return 0
    fi

    if efibootmgr --create --disk "$disk" --part 1 \
        --label "NixOS" \
        --loader '\EFI\systemd\systemd-bootx64.efi' \
        >/dev/null 2>&1; then
        log "Registered EFI boot entry: NixOS -> \\EFI\\systemd\\systemd-bootx64.efi"
        nds_install_log "EFI boot entry registered for ${disk}1"
    else
        warn "efibootmgr could not create the boot entry — add it manually in firmware."
        warn "Loader: \\EFI\\systemd\\systemd-bootx64.efi on ${disk}1"
    fi
    return 0
}
