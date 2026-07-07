#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub CLI session helpers (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Resolve gh command (host binary or nix shell).
# Arguments:
# - out: <Nameref> Command prefix array
# Returns:
# - <Bool> 0 when gh is available
nds_git_gh_cmd() {
    local -n _out=$1
    if command -v gh &>/dev/null; then
        _out=(gh)
    elif command -v nix &>/dev/null; then
        _out=(nix --extra-experimental-features "nix-command flakes" shell nixpkgs#gh -c gh)
    else
        _out=()
        return 1
    fi
    return 0
}

# Description: True when gh is logged in to github.com.
# Returns:
# - <Bool> 0 when session is active
nds_git_gh_session_active() {
    local -a gh_cmd=()
    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" auth status &>/dev/null
}

# Description: True when token has admin:public_key scope.
# Returns:
# - <Bool> 0 when scope is present
nds_git_gh_has_key_scope() {
    local -a gh_cmd=()
    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" auth status --show-token-scopes 2>/dev/null | grep -qF 'admin:public_key'
}

# Description: End temporary gh auth on the live ISO (SSH keys on GitHub are kept).
nds_git_gh_session_cleanup() {
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 0
    if "${gh_cmd[@]}" auth status &>/dev/null; then
        "${gh_cmd[@]}" auth logout --hostname github.com 2>/dev/null || true
        nds_install_log "git: gh session cleared from live ISO (SSH key left on GitHub)"
    fi
}

# Description: True when gh CLI is available on the live ISO.
# Returns:
# - <Bool> 0 when gh can be invoked
nds_git_gh_available() {
    local -a gh_cmd=()
    nds_git_gh_cmd gh_cmd
}
