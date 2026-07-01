#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-01
# Description:   Admin user credential generation for NixOS installation
# Feature:       Auto-generate or collect the admin password, save to runtime secrets
# ==================================================================================================

# Description: Resolve the admin password (auto-generate from /dev/urandom or
# use the user-supplied value) and write it to the runtime secrets dir so the
# access nixcfg block can embed it and the install backup bundle can ship it.
# Run before writing configuration.nix. Uses /dev/urandom (no openssl on the
# live ISO).
_nixinstall_generate_access_secrets() {
    local auto length manual runtime_secrets pw_file pw

    auto=$(nds_config_get "access" "ADMIN_PASSWORD_AUTO")
    length=$(nds_config_get "access" "ADMIN_PASSWORD_LENGTH")
    manual=$(nds_config_get "access" "ADMIN_PASSWORD")

    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"
    mkdir -p "$runtime_secrets" || { error "Cannot create secrets dir"; return 1; }
    pw_file="$runtime_secrets/admin_password.txt"

    if [[ "$auto" == "true" ]]; then
        log "Generating admin password (/dev/urandom, $length bytes -> $((length * 2)) hex chars)"
        pw=$(od -An -tx1 -v -N "$length" /dev/urandom | tr -d ' \n')
        if [[ -z "$pw" ]]; then
            error "Admin password generation from /dev/urandom failed"
            return 1
        fi
    else
        pw="$manual"
        if [[ -z "$pw" ]]; then
            error "Auto-generate is off but no admin password was set"
            return 1
        fi
    fi

    printf '%s' "$pw" > "$pw_file"
    chmod 600 "$pw_file"
    [[ -s "$pw_file" ]] || { error "Failed to write admin password file"; return 1; }
    nds_install_log "Generated admin password (saved to secrets/admin_password.txt)"
    return 0
}
