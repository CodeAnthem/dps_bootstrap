#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install pipeline
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

# Description: Full classic NixOS install (disk prep + nixos-install).
nds_nixos_install() {
    _nixinstall_gather_context
    nds_install_log "classicInstall: nds_nixos_install starting"
    nds_preflight_install "$NDS_CTX_DISK" || return 1

    NDS_UI_QUIET=true

    if ! nds_nixinstall_auto; then
        return 1
    fi

    if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
        cp /mnt/etc/nixos/hardware-configuration.nix "$NDS_RUNTIME_DIR/config/"
    elif [[ -f /mnt/etc/nixos/facter.json ]]; then
        cp /mnt/etc/nixos/facter.json "$NDS_RUNTIME_DIR/config/"
    fi

    nds_step_exec "Installing configuration files" _nixinstall_install_configs || return 1
    nds_step_exec "Installing NixOS" _nixinstall_install_nixos || return 1
    nds_step_exec "Registering EFI boot entry" _nixinstall_register_efi_entry "$NDS_CTX_DISK" || true

    nds_install_log "classicInstall: completed"
    return 0
}
