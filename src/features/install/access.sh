#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-28
# Description:   Admin user credential generation adapters for NixOS installation
# Feature:       Auto-generate or collect the admin password, save to runtime secrets
# ==================================================================================================

# Description: Resolve the admin password and write runtime secrets (NDS adapter).
# Run before writing configuration.nix.
_nixinstall_generate_access_secrets() {
    local runtime_secrets

    nds_install_ctx_ensure
    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    nds_install_write_admin_password \
        "${NDS_CTX_ADMIN_PASSWORD_AUTO}" \
        "${NDS_CTX_ADMIN_PASSWORD_LENGTH}" \
        "${NDS_CTX_ADMIN_PASSWORD}" \
        "$runtime_secrets" || return 1

    nds_install_log "Generated admin password (saved to secrets/admin_password.txt)"
    return 0
}
