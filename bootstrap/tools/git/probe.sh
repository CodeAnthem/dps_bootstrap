#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git probe and clone
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
# Description:   Non-interactive git access probe and clone wrapper
# ==================================================================================================

# Description: Non-interactively test whether a repo is reachable with loaded SSH keys.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when accessible
nds_git_probe_access() {
    local url="$1" ssh_url
    ssh_url=$(_nds_git_ssh_url "$url")
    local -a envv=()
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env)
    env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
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
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env)

    if [[ "$depth" == "0" ]]; then
        env "${envv[@]}" git -c credential.helper= clone "$ssh_url" "$dest"
    else
        env "${envv[@]}" git -c credential.helper= clone --depth "$depth" "$ssh_url" "$dest"
    fi
}
