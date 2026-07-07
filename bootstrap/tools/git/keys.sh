#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key registry (multi-key / deploy-key support)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Registry file listing session private key paths (one per line).
_nds_git_keys_registry_file() {
    printf '%s/git_session_keys\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Filesystem slug from owner and repo names.
# Arguments:
# - owner: <String> Git owner/org
# - repo:  <String> Repository name
# Returns:
# - <String> slug e.g. codeanthem-dps-swarm (stdout)
_nds_git_repo_slug() {
    local owner="$1" repo="$2"
    local o r

    o=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
    o=$(printf '%s' "$o" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
    r=$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')
    r=$(printf '%s' "$r" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
    printf '%s-%s\n' "$o" "$r"
}

# Description: Register a private key path for this NDS session.
# Arguments:
# - key_path: <String> Private key file
nds_git_keys_register() {
    local key_path="$1"
    local reg

    [[ -f "$key_path" ]] || return 1
    reg="$(_nds_git_keys_registry_file)"
    mkdir -p "$(dirname "$reg")"
    if [[ -f "$reg" ]] && grep -qxF "$key_path" "$reg" 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "$key_path" >> "$reg"
    nds_git_key_load "$key_path" || true
    return 0
}

# Description: List registered session private key paths.
# Returns:
# - <String> paths (stdout, one per line)
nds_git_keys_list() {
    local reg key_path

    {
        reg="$(_nds_git_keys_registry_file)"
        if [[ -f "$reg" ]]; then
            while IFS= read -r key_path; do
                [[ -f "$key_path" ]] && printf '%s\n' "$key_path"
            done < "$reg"
        fi
        key_path="$(nds_git_session_key_path 2>/dev/null || true)"
        if [[ -n "$key_path" && -f "$key_path" ]]; then
            printf '%s\n' "$key_path"
        fi
    } | awk 'NF' | sort -u
}

# Description: Load all registered keys into ssh-agent.
nds_git_keys_load_all() {
    local key_path

    while IFS= read -r key_path; do
        [[ -n "$key_path" && -f "$key_path" ]] || continue
        nds_git_key_load "$key_path" || true
    done < <(nds_git_keys_list)
}

# Description: Persist auth mode for closure behaviour (deploy|account|imported).
# Arguments:
# - mode: <String> deploy, account, or imported
nds_git_auth_set_mode() {
    local mode="$1"
    export NDS_GIT_AUTH_MODE="$mode"
    nds_cfg_set GIT_AUTH_MODE "$mode"
}

# Description: Current git auth mode (deploy, account, imported, or empty).
# Returns:
# - <String> mode (stdout)
nds_git_auth_mode() {
    local mode="${NDS_GIT_AUTH_MODE:-}"
    [[ -n "$mode" ]] || mode="$(nds_cfg_get GIT_AUTH_MODE 2>/dev/null || true)"
    printf '%s\n' "$mode"
}

# Description: Basename for a per-repo deploy key file.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. deploy-codeanthem-dps-swarm (stdout)
nds_git_deploy_key_basename() {
    local owner="$1" repo="$2"
    printf 'deploy-%s\n' "$(_nds_git_repo_slug "$owner" "$repo")"
}

# Description: Session path for a per-repo deploy private key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> path under /root/.ssh (stdout)
nds_git_deploy_key_path() {
    local owner="$1" repo="$2"
    printf '/root/.ssh/%s\n' "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Deploy key title for GitHub registration.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> title (stdout)
nds_git_deploy_key_title() {
    local owner="$1" repo="$2"
    printf 'nds-%s\n' "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Target install path relative to mount root for a deploy key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. etc/nixos/secrets/deploy-codeanthem-dps-swarm (stdout)
nds_git_deploy_key_target_rel() {
    local owner="$1" repo="$2"
    printf 'etc/nixos/secrets/%s\n' "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Public key path for a per-repo deploy key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> .pub path (stdout)
nds_git_deploy_key_pubkey_path() {
    printf '%s.pub\n' "$(nds_git_deploy_key_path "$1" "$2")"
}

# Description: Generate or reuse a deploy key for one repository.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <Bool> 0 on success
nds_git_deploy_key_generate() {
    local owner="$1" repo="$2"
    local dest title

    dest="$(nds_git_deploy_key_path "$owner" "$repo")"
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    nds_git_key_generate "$dest" "$title" || return 1
    nds_git_keys_register "$dest" || return 1
    nds_git_auth_set_mode deploy
    return 0
}

# Description: Relative path for target SSH config fragment.
# Returns:
# - <String> etc/ssh/ssh_config.d/nds-git.conf (stdout)
nds_git_target_ssh_config_rel() {
    printf 'etc/ssh/ssh_config.d/nds-git.conf\n'
}

# Description: Install all session keys and SSH config onto the target under /mnt.
# Arguments:
# - mount_root: <String|optional> Target mount (default /mnt)
# Returns:
# - <Bool> 0 on success or when skipped
nds_git_install_keys_to_target() {
    local mount_root="${1:-/mnt}"
    local -a keys=()
    local key_path base dest_rel dest_dir dest abs target_cfg
    local -a identity_lines=()

    [[ -d "$mount_root" ]] || {
        debug "Target mount missing — skip git SSH key install"
        return 0
    }

    mapfile -t keys < <(nds_git_keys_list)
    [[ ${#keys[@]} -gt 0 ]] || {
        nds_git_install_key_to_target "" "$mount_root" || return 0
        return 0
    }

    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" ]] || continue
        base="$(basename "$key_path")"
        dest_rel="etc/nixos/secrets/${base}"
        dest="${mount_root}/${dest_rel}"
        dest_dir="$(dirname "$dest")"
        mkdir -p "$dest_dir"
        install -m 600 -o root -g root "$key_path" "$dest"
        abs="/${dest_rel}"
        identity_lines+=("  IdentityFile ${abs}")
        nds_install_log "git: SSH key -> ${abs}"
    done

    [[ ${#identity_lines[@]} -gt 0 ]] || return 0

    target_cfg="${mount_root}/$(nds_git_target_ssh_config_rel)"
    mkdir -p "$(dirname "$target_cfg")"
    {
        printf '%s\n' "Host github.com *.github.com"
        printf '%s\n' "${identity_lines[@]}"
        printf '%s\n' "  IdentitiesOnly yes"
    } > "$target_cfg"
    chmod 644 "$target_cfg"

    NDS_GIT_TARGET_SSH_CONFIG_ABS="/$(nds_git_target_ssh_config_rel)"
    export NDS_GIT_TARGET_SSH_CONFIG_ABS
    log "Git SSH config installed on target: ${NDS_GIT_TARGET_SSH_CONFIG_ABS}"
    nds_install_log "git: SSH config -> ${NDS_GIT_TARGET_SSH_CONFIG_ABS} (${#keys[@]} key(s))"
    return 0
}
