#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git probe and clone
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
# Description:   Non-interactive git access probe and clone wrapper
# ==================================================================================================

# Description: GIT_SSH_COMMAND without any identity (anonymous probe).
_nds_git_ssh_env_bare() {
    printf '%s\n' \
        "GIT_TERMINAL_PROMPT=0" \
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o IdentitiesOnly=yes"
}

# Description: True when a repo is reachable without SSH keys (public).
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when ls-remote succeeds without credentials
nds_git_probe_public() {
    local url="$1" ssh_url
    local -a envv=()

    ssh_url=$(_nds_git_ssh_url "$url")
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env_bare)
    if command -v timeout &>/dev/null; then
        timeout 8 env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    else
        env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    fi
}

# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when accessible
nds_git_probe_access() {
    local url="$1" ssh_url key_path=""
    ssh_url=$(_nds_git_ssh_url "$url")
    local -a envv=()
    key_path=$(_nds_git_identity_for_url "$url" 2>/dev/null || true)
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env_for_url "$url")
    if command -v timeout &>/dev/null; then
        timeout 15 env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    else
        env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    fi
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        debug "git probe failed: ${ssh_url} key=${key_path:-none}"
        nds_install_log "git: probe failed ${ssh_url} (key=${key_path:-none})"
    fi
    return "$rc"
}

# Description: Clone a flake using SSH deploy-key auth.
# Arguments:
# - url:   <String> Git URL (HTTPS URLs are converted to SSH when parseable)
# - dest:  <String> Destination directory
# - depth: <Int|optional> Clone depth (default 1; 0 = full clone)
# Returns:
# - <Bool> 0 on success
nds_git_clone() {
    local url="$1" dest="$2" depth="${3:-1}" ssh_url
    ssh_url=$(_nds_git_ssh_url "$url")
    local -a envv=()
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env_for_url "$url")

    if [[ "$depth" == "0" ]]; then
        env "${envv[@]}" git -c credential.helper= clone "$ssh_url" "$dest"
    else
        env "${envv[@]}" git -c credential.helper= clone --depth "$depth" "$ssh_url" "$dest"
    fi
}
