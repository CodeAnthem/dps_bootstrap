#!/usr/bin/env bash
# ==================================================================================================
# NDS - sops age key enrollment
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-03 | Modified: 2026-07-07
# Description:   Generate a machine age key, install it on the target, and guide sops enrollment
# ==================================================================================================

# Run age-keygen via shared tools helper (PATH or nixpkgs#age).
_sops_run_age_keygen() {
    local nix_config
    nix_config=$(_install_nix_combined_nix_config "experimental-features = nix-command flakes")
    NDS_PKG_NIX_CONFIG="$nix_config" nds_age_keygen "$@"
}

# Description: Write an operator note describing how to enroll a machine pubkey.
# Arguments:
# - dest:     <String> Note file path
# - hostname: <String> Host name
# - pubkey:   <String> Machine age public key
_sops_write_enroll_note() {
    local dest="$1"
    local hostname="$2"
    local pubkey="$3"

    cat > "$dest" << EOF
# sops enrollment for ${hostname}

Machine age public key:

    ${pubkey}

To grant this machine access to its secrets:

1. Add the public key to .sops.yaml under the relevant creation_rules
   (host-specific: secrets/hosts/${hostname}/*.yaml; shared: secrets/*.yaml).
2. Re-encrypt affected secrets so the new recipient can decrypt them:

    sops updatekeys secrets/secrets.yaml
    # repeat for any secrets/hosts/${hostname}/*.yaml

3. Commit .sops.yaml and the updated secrets, then deploy.

The matching private key is installed on the machine at
/etc/sops/age/keys.txt and is backed up in this bundle as
secrets/machine_age_key.txt — keep it safe and offline.
EOF
}

# Description: Generate/enroll a machine age key for sops-nix.
# Generates a key (idempotent), installs the private key to the target under
# /etc/sops/age/keys.txt, saves pubkey + a copy of the private key into the
# runtime secrets dir for the backup bundle, and emits enrollment instructions.
# Full .sops.yaml editing is left to the operator (add pubkey + sops updatekeys).
# Arguments:
# - flake_root: <String> Path to the flake checkout
# - hostname:   <String> Host name
# - target_root: <String|optional> Installed system root (default: /mnt)
# Returns:
# - <Bool> 0 on success or when sops is not used; 1 when enrollment fails for a sops flake
_sops_enroll_key() {
    local flake_root="$1"
    local hostname="$2"
    local target_root="${3:-/mnt}"
    local sops_yaml="${flake_root}/.sops.yaml"
    local secrets_dir="${NDS_RUNTIME_DIR}/secrets"
    local age_dir="${secrets_dir}/age"
    local key_file="${age_dir}/keys.txt"
    local pubkey

    if [[ -z "$flake_root" || ! -d "$flake_root" ]]; then
        debug "No flake root — skipping sops enrollment"
        return 0
    fi

    if [[ ! -f "$sops_yaml" ]]; then
        warn "No .sops.yaml found in ${flake_root} — skipping sops enrollment"
        return 0
    fi

    mkdir -p "$age_dir" || {
        error "Cannot create $age_dir — sops enrollment failed"
        return 1
    }

    if [[ ! -f "$key_file" ]]; then
        if ! _sops_run_age_keygen -o "$key_file" \
            2>>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"; then
            error "age-keygen failed — cannot generate machine age key"
            return 1
        fi
        chmod 600 "$key_file"
    fi

    if ! pubkey=$(_sops_run_age_keygen -y "$key_file" 2>/dev/null); then
        error "Could not derive age public key from $key_file"
        return 1
    fi

    # Persist pubkey + a bundle-visible copy of the private key (DR).
    echo "$pubkey" > "${secrets_dir}/age_pubkey.txt"
    cp "$key_file" "${secrets_dir}/machine_age_key.txt"
    chmod 600 "${secrets_dir}/machine_age_key.txt"
    _sops_write_enroll_note "${secrets_dir}/sops_enroll.md" "$hostname" "$pubkey"

    log "Machine age public key: $pubkey"

    # Install the private key onto the target system (local install).
    if [[ -d "${target_root}/etc" ]]; then
        mkdir -p "${target_root}/etc/sops/age"
        cp "$key_file" "${target_root}/etc/sops/age/keys.txt"
        chmod 600 "${target_root}/etc/sops/age/keys.txt"
        log "Installed machine age key to ${target_root}/etc/sops/age/keys.txt"
    else
        error "${target_root}/etc not found — machine age key not installed to target"
        return 1
    fi

    warn "Enroll ${hostname} in .sops.yaml, then run: sops updatekeys secrets/secrets.yaml"
    log "Enrollment instructions saved to bundle: secrets/sops_enroll.md"
    nds_install_log "sops: enrolled ${hostname} (${pubkey})"
    return 0
}
