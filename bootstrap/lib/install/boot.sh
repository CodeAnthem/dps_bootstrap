#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-07
# Description:   Bootloader registration (EFI NVRAM entry)
# Feature:       No keyfile is placed on the target — LUKS key (if used) lives on a USB stick
# ==================================================================================================

# Description: Whether the live system (or configured mode) is UEFI.
# Uses BOOT_UEFI_MODE when set; otherwise detects from firmware.
# Returns:
# - <Bool> 0 when UEFI
_nds_install_live_is_uefi() {
    local configured
    configured=$(nds_config_get "boot" "BOOT_UEFI_MODE" 2>/dev/null || true)
    if [[ "$configured" == "true" ]]; then return 0; fi
    if [[ "$configured" == "false" ]]; then return 1; fi
    [[ -d /sys/firmware/efi/efivars ]]
}

# Description: EFI loader path for efibootmgr from the configured bootloader preset.
# Returns:
# - <String> Backslash-separated EFI path (stdout)
_nixinstall_efi_loader_path() {
    local loader
    loader=$(nds_config_get "boot" "BOOT_LOADER" 2>/dev/null || true)
    loader="${loader:-systemd-boot}"
    case "$loader" in
        grub) printf '%s' '\\EFI\\nixos\\grubx64.efi' ;;
        refind) printf '%s' '\\EFI\\refind\\refind_x64.efi' ;;
        systemd-boot|*) printf '%s' '\\EFI\\systemd\\systemd-bootx64.efi' ;;
    esac
}

# Description: Register the NixOS EFI boot entry in firmware NVRAM.
# nixos-install runs bootctl in a chroot where efivars is not writable, so the
# bootloader files are copied but no NVRAM entry is created — some firmware
# (e.g. VMware) then shows "no OS found". This writes the entry from the host.
# Arguments:
# - disk: <String> Target block device (ESP is partition 1)
# Returns:
# - <Bool> 0 on success or when BIOS mode; 1 when UEFI registration fails
_nixinstall_register_efi_entry() {
    local disk="$1"
    local loader_path

    _nds_install_live_is_uefi || return 0

    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        error "Configured UEFI install but live ISO is not booted in UEFI mode"
        error "Boot the NixOS ISO in UEFI mode, or pick a BIOS bootloader (GRUB)"
        return 1
    fi

    loader_path=$(_nixinstall_efi_loader_path)

    if ! command -v efibootmgr &>/dev/null; then
        error "efibootmgr not available — cannot register EFI boot entry"
        error "Loader: ${loader_path} on ${disk}1"
        return 1
    fi

    if efibootmgr --create --disk "$disk" --part 1 \
        --label "NixOS" \
        --loader "$loader_path" \
        >/dev/null 2>&1; then
        log "Registered EFI boot entry: NixOS -> ${loader_path}"
        nds_install_log "EFI boot entry registered for ${disk}1 (${loader_path})"
        return 0
    fi

    error "efibootmgr could not create the boot entry"
    error "Loader: ${loader_path} on ${disk}1"
    return 1
}
