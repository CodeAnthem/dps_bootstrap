#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install pipeline
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-07
# ==================================================================================================

# Description: Full classic NixOS install (disk prep + nixos-install).
nds_nixos_install() {
    _install_gather_context
    nds_install_log "classicInstall: nds_nixos_install starting"
    nds_preflight_install "$NDS_CTX_DISK" "$NDS_CTX_BOOT_UEFI_MODE" "$NDS_CTX_BOOT_LOADER" || return 1

    NDS_UI_QUIET=true

    if ! nds_install_auto; then
        return 1
    fi

    if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
        cp /mnt/etc/nixos/hardware-configuration.nix "$NDS_RUNTIME_DIR/config/"
    elif [[ -f /mnt/etc/nixos/facter.json ]]; then
        cp /mnt/etc/nixos/facter.json "$NDS_RUNTIME_DIR/config/"
    fi

    nds_step_exec "Installing configuration files" _install_configs || return 1
    nds_step_exec "Installing NixOS" _install_nixos || return 1
    nds_step_exec "Registering EFI boot entry" _install_register_efi_entry "$NDS_CTX_DISK" || return 1
    nds_step_exec "Verifying installation" nds_install_verify_local || return 1

    nds_install_log "classicInstall: completed"
    return 0
}
