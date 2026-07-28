#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key operations (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Generate, import, load, install git SSH keys (argument-only)
# ==================================================================================================

# Description: Load a private key into ssh-agent (starts agent if needed).
# Arguments:
# - key_path: <String> Private key path
# Returns:
# - <Bool> 0 on success
nds_git_key_load_path() {
    local key_path="$1"

    [[ -f "$key_path" ]] || return 1
    if ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    fi
    ssh-add "$key_path" >/dev/null 2>&1
}

# Description: Copy a private key into place with safe permissions and load into ssh-agent.
# Arguments:
# - src:  <String> Source private key file
# - dest: <String> Destination path
# Returns:
# - <Bool> 0 on success
nds_git_key_import_to() {
    local src="$1" dest="$2"

    [[ -f "$src" ]] || {
        if declare -f error &>/dev/null; then
            error "SSH key not found: $src"
        fi
        return 1
    }
    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    cp "$src" "$dest"
    chmod 600 "$dest"
    nds_git_key_load_path "$dest"
}

# Description: Generate an ed25519 git SSH key pair (reuses existing file when present).
# Arguments:
# - dest:         <String> Private key path
# - comment:      <String> Key comment
# - force_regen:  <Bool|optional> When true, replace an existing key
# Returns:
# - <Bool> 0 on success
nds_git_key_generate_at() {
    local dest="$1" comment="$2" force_regen="${3:-false}"

    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    if [[ -f "$dest" && "$force_regen" != "true" ]]; then
        nds_git_key_load_path "$dest"
        if declare -f log &>/dev/null; then
            log "Reusing git SSH key (${comment}) at ${dest}"
        fi
        return 0
    fi
    rm -f "$dest" "${dest}.pub"
    ssh-keygen -t ed25519 -N "" -f "$dest" -C "$comment" >/dev/null 2>&1 || {
        if declare -f error &>/dev/null; then
            error "ssh-keygen failed"
        fi
        return 1
    }
    chmod 600 "$dest"
    nds_git_key_load_path "$dest"
    if declare -f log &>/dev/null; then
        log "Git SSH key generated (${comment})"
    fi
}

# Description: Install a private key onto a target root mount.
# Arguments:
# - key_path:   <String> Source private key
# - mount_root: <String> Target mount (e.g. /mnt)
# - dest_rel:   <String> Path relative to mount
# Returns:
# - <Bool> 0 on success or when skipped
nds_git_key_install_to_mount() {
    local key_path="$1" mount_root="$2" dest_rel="$3"
    local dest_dir dest

    [[ -f "$key_path" ]] || return 0
    [[ -d "$mount_root" ]] || return 0

    dest="${mount_root}/${dest_rel}"
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"
    install -m 600 -o root -g root "$key_path" "$dest"
    return 0
}
