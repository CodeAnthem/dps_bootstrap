#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key management (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Session SSH key paths, import, generate, load, target install
# ==================================================================================================

# Description: Active private git SSH key path for this NDS session (persists under /root/.ssh).
# Returns:
# - <String> Key file path (stdout)
nds_git_session_key_path() {
    local slug base

    if [[ -n "${NDS_GIT_SESSION_KEY_PATH:-}" ]]; then
        printf '%s\n' "$NDS_GIT_SESSION_KEY_PATH"
        return 0
    fi
    slug="$(nds_git_owner_slug)"
    if [[ "$slug" != "unknown" ]]; then
        base="$(nds_git_secrets_basename)"
        printf '/root/.ssh/%s\n' "$base"
    else
        printf '/root/.ssh/git-unknown-key\n'
    fi
}

# Description: Basename for owner-scoped git SSH key files (e.g. git-codeanthem-key).
# Returns:
# - <String> basename without directory (stdout)
nds_git_secrets_basename() {
    printf 'git-%s-key\n' "$(nds_git_owner_slug)"
}

# Description: Target install path relative to mount root.
# Returns:
# - <String> e.g. etc/nixos/secrets/git-codeanthem-key (stdout)
nds_git_target_key_rel() {
    printf 'etc/nixos/secrets/%s\n' "$(nds_git_secrets_basename)"
}

# Description: Absolute path on installed system.
# Returns:
# - <String> e.g. /etc/nixos/secrets/git-codeanthem-key (stdout)
nds_git_target_key_abs() {
    printf '/%s\n' "$(nds_git_target_key_rel)"
}

# Description: Public key path for the session git SSH key.
# Returns:
# - <String> .pub path (stdout)
nds_git_session_pubkey_path() {
    local key
    key="$(nds_git_session_key_path)"
    printf '%s\n' "${key}.pub"
}

# Description: SSH key title / ssh-keygen comment (owner + flake host when known).
# Returns:
# - <String> e.g. nds-codeanthem-control-toolkit
nds_git_ssh_key_title() {
    local name="" slug=""

    if declare -f nds_configurator_config_get &>/dev/null; then
        name="$(nds_configurator_config_get FLAKE_HOST 2>/dev/null || true)"
    fi
    [[ -z "$name" ]] && name="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
    [[ -z "$name" ]] && name="$(nds_cfg_get NETWORK_HOSTNAME 2>/dev/null || true)"
    [[ -z "$name" ]] && name="$(hostname -s 2>/dev/null || echo live)"
    slug="$(nds_git_owner_slug)"
    if [[ "$slug" != "unknown" ]]; then
        printf 'nds-%s-%s' "$slug" "$name"
    else
        printf 'nds-%s' "$name"
    fi
}

# Description: Copy a private key into place with safe permissions and load into ssh-agent.
# Arguments:
# - src:  <String> Source private key file
# - dest: <String|optional> Destination path (default session key path)
# Returns:
# - <Bool> 0 on success
nds_git_key_import() {
    local src="$1" dest="${2:-$(nds_git_session_key_path)}"

    [[ -f "$src" ]] || { error "SSH key not found: $src"; return 1; }
    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    cp "$src" "$dest"
    chmod 600 "$dest"
    nds_git_key_load "$dest"
}

# Description: Load a private key into ssh-agent (starts agent if needed).
# Arguments:
# - key_path: <String|optional> Private key path
# Returns:
# - <Bool> 0 on success
nds_git_key_load() {
    local key_path="${1:-$(nds_git_session_key_path)}"

    [[ -f "$key_path" ]] || return 1
    if ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    fi
    ssh-add "$key_path" >/dev/null 2>&1
}

# Description: Generate an ed25519 git SSH key pair (reuses existing file when present).
# Arguments:
# - dest:    <String|optional> Private key path
# - comment: <String|optional> Key comment (default nds-<owner>-<flake host>)
# Returns:
# - <Bool> 0 on success
nds_git_key_generate() {
    local dest="${1:-$(nds_git_session_key_path)}"
    local comment="${2:-$(nds_git_ssh_key_title)}"

    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    if [[ -f "$dest" && "${NDS_GIT_KEY_FORCE_REGEN:-false}" != "true" ]]; then
        nds_git_key_load "$dest"
        log "Reusing git SSH key (${comment}) at ${dest}"
        return 0
    fi
    rm -f "$dest" "${dest}.pub"
    ssh-keygen -t ed25519 -N "" -f "$dest" -C "$comment" >/dev/null 2>&1 || {
        error "ssh-keygen failed"
        return 1
    }
    chmod 600 "$dest"
    nds_git_key_load "$dest"
    log "Git SSH key generated (${comment})"
}

# Description: Install session git SSH private key onto the target root under /mnt.
# Arguments:
# - key_path:   <String|optional> Source private key
# - mount_root: <String|optional> Target mount (default /mnt)
# - dest_rel:   <String|optional> Path relative to mount
# Returns:
# - <Bool> 0 on success or when skipped
nds_git_install_key_to_target() {
    local key_path="${1:-$(nds_git_session_key_path)}"
    local mount_root="${2:-/mnt}"
    local dest_rel="${3:-$(nds_git_target_key_rel)}"
    local dest_dir dest

    [[ -f "$key_path" ]] || {
        debug "No session git SSH key — skip target install"
        return 0
    }
    [[ -d "$mount_root" ]] || {
        debug "Target mount missing — skip git SSH key install"
        return 0
    }

    dest="${mount_root}/${dest_rel}"
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"
    install -m 600 -o root -g root "$key_path" "$dest"
    export NDS_GIT_TARGET_KEY_REL="$dest_rel"
    export NDS_GIT_TARGET_KEY_ABS="/${dest_rel}"
    log "Git SSH key installed on target: ${NDS_GIT_TARGET_KEY_ABS} (mode 600, excluded from backup zip)"
    nds_install_log "git: SSH key -> ${NDS_GIT_TARGET_KEY_ABS} (persists for flake/git fetches after reboot)"
    return 0
}

# Description: Load persisted session key from /root/.ssh when NDS restarts on the live ISO.
# Returns:
# - <Bool> 0 when an existing session key was loaded
nds_git_auth_try_session_key() {
    local dest

    dest="$(nds_git_session_key_path)"
    [[ -f "$dest" ]] || return 1
    nds_git_key_load "$dest" || return 1
    debug "Reused persisted git SSH key: ${dest}"
    return 0
}

# Description: Try loading NDS_GIT_IMPORT_KEY_PATH before interactive auth.
# Returns:
# - <Bool> 0 when key was imported and loaded
nds_git_auth_try_import_path() {
    local path="${NDS_GIT_IMPORT_KEY_PATH:-${NDS_DEPLOY_KEY_PATH:-}}"
    local dest
    [[ -n "$path" && -f "$path" ]] || return 1
    dest="$(nds_git_session_key_path)"
    if [[ "$path" == "$dest" ]]; then
        nds_git_key_load "$dest" || return 1
    else
        nds_git_key_import "$path" "$dest" || return 1
    fi
    debug "Loaded SSH key from import path"
    return 0
}

# Compatibility aliases (deprecated names).
nds_git_install_deploy_key_to_target() { nds_git_install_key_to_target "$@"; }
nds_git_auth_try_deploy_key_path() { nds_git_auth_try_import_path; }
