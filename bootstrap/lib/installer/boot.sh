#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bootloader registration
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-06-30
# Description:   Place the LUKS keyfile on the target and register the EFI boot entry
# ==================================================================================================

# Description: Install the LUKS keyfile onto the target root so the initrd can
# unlock cryptroot at boot. Only for the keyfile-unlock case (no passphrase,
# no remote dropbear unlock). Must run before nixos-install builds the system.
# Usage: _nixinstall_install_luks_keyfile
_nixinstall_install_luks_keyfile() {
    local encryption use_passphrase remote_unlock
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    use_passphrase=$(nds_config_get "disk" "ENCRYPTION_USE_PASSPHRASE")
    remote_unlock=$(nds_config_get "disk" "REMOTE_UNLOCK")

    [[ "$encryption" == "true" \
        && "$use_passphrase" != "true" \
        && "$remote_unlock" != "true" ]] || return 0

    if [[ -z "${NDS_ENCRYPTION_KEY:-}" ]]; then
        if [[ -n "${NDS_KEY_FILE:-}" && -f "$NDS_KEY_FILE" ]]; then
            NDS_ENCRYPTION_KEY=$(<"$NDS_KEY_FILE")
        elif [[ -f "${NDS_RUNTIME_DIR:-}/secrets/luks_key.txt" ]]; then
            NDS_ENCRYPTION_KEY=$(<"${NDS_RUNTIME_DIR}/secrets/luks_key.txt")
        else
            error "LUKS key not available — cannot install keyfile"
            return 1
        fi
    fi

    local keydir="/mnt/etc/luks-keys"
    mkdir -p "$keydir" || return 1
    # No trailing newline: must match the bytes used in cryptsetup luksFormat.
    printf '%s' "$NDS_ENCRYPTION_KEY" > "$keydir/cryptroot" || return 1
    chmod 600 "$keydir/cryptroot" || return 1

    log "LUKS keyfile installed to /etc/luks-keys/cryptroot"
    nds_install_log "LUKS keyfile installed for initrd unlock"
    return 0
}

# Description: Register the NixOS EFI boot entry in firmware NVRAM.
# nixos-install runs bootctl in a chroot where efivars is not writable, so the
# bootloader files are copied but no NVRAM entry is created — some firmware
# (e.g. VMware) then shows "no OS found". This writes the entry from the host.
# Arguments:
# - disk: <String> Target block device (ESP is partition 1)
_nixinstall_register_efi_entry() {
    local disk="$1"
    local uefi

    uefi=$(nds_config_get "boot" "UEFI_MODE")
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
