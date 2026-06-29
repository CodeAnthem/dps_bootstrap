#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-06-27
# Description:   Initrd SSH host keys for remote LUKS unlock (install-time only)
# ==================================================================================================

# Generate initrd SSH host keys on the target root (standard NixOS paths).
# Usage: _nixinstall_setup_initrd_ssh_keys
_nixinstall_setup_initrd_ssh_keys() {
    local ssh_dir="/mnt/etc/ssh"

    log "Generating initrd SSH host keys for remote unlock"
    mkdir -p "$ssh_dir"
    chmod 755 "$ssh_dir"

    if [[ -f "$ssh_dir/initrd_ssh_host_ed25519_key" ]]; then
        warn "Initrd SSH host key already exists — skipping"
        return 0
    fi

    ssh-keygen -t ed25519 -f "$ssh_dir/initrd_ssh_host_ed25519_key" -N "" -C "initrd-remote-unlock" || return 1
    chmod 600 "$ssh_dir/initrd_ssh_host_ed25519_key"
    chmod 644 "$ssh_dir/initrd_ssh_host_ed25519_key.pub"

    success "Initrd SSH host keys written to $ssh_dir"
    return 0
}
