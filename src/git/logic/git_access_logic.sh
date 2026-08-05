#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access logic (no TTY)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Probe / map / existing-key access from config AA
# ==================================================================================================

# Description: Normalize repo URL into cfg AA (SSH form when parseable).
# Arguments:
# - cfg: <Nameref> Config AA (FLAKE_REPO_URL)
# Returns:
# - 0 when URL is a git remote; 1 when empty/non-git
nds_git_access_logic_normalize() {
    local -n _g_cfg=$1
    local url parsed host owner repo ssh_url

    url="${_g_cfg[FLAKE_REPO_URL]:-}"
    [[ -n "$url" ]] || return 1
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 1 ;;
    esac

    if parsed=$(_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$url" != git@* && "$url" != ssh://* ]]; then
            ssh_url="$(_git_to_ssh "$host" "$owner" "$repo")"
            _g_cfg[FLAKE_REPO_URL]="$ssh_url"
            _g_cfg[FLAKE_LOCATION]="$ssh_url"
            _g_cfg[FLAKE_LOCAL_PATH]=""
            _g_cfg[FLAKE_SOURCE]="remote"
            url="$ssh_url"
        fi
        _g_cfg[GIT_ACCESS_HOST]="$host"
        _g_cfg[GIT_ACCESS_OWNER]="$owner"
        _g_cfg[GIT_ACCESS_REPO]="$repo"
    fi
    return 0
}

# Description: Try public / map / existing keys for cfg FLAKE_REPO_URL.
# Arguments:
# - cfg: <Nameref> Config AA
# Returns:
# - 0 when access works without interactive auth
nds_git_access_logic_try() {
    local -n _g_try=$1
    local url="${_g_try[FLAKE_REPO_URL]:-}"
    local owner="${_g_try[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_try[GIT_ACCESS_REPO]:-}"

    [[ -n "$url" ]] || return 1

    if nds_git_probe_public "$url" 2>/dev/null; then
        success "Public repository ${owner}/${repo} — no SSH key required."
        nds_install_log "git: public repo ${owner}/${repo}"
        nds_git_access_mark_verified
        _g_try[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi

    if declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
        success "Git access confirmed for ${owner}/${repo} (configured map)."
        nds_git_access_mark_verified
        _g_try[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi

    if _git_auth_try_existing_access "$url"; then
        success "Git access confirmed for ${owner}/${repo} (existing key)."
        nds_git_access_mark_verified
        if declare -f nds_git_access_set &>/dev/null; then
            nds_git_access_set method "$url" "import"
        fi
        _g_try[GIT_ACCESS_VERIFIED]="true"
        _g_try[GIT_ACCESS_METHOD]="import"
        return 0
    fi
    return 1
}

# Description: Probe access after keys were registered (post-prompts).
nds_git_access_logic_verify() {
    local -n _g_ver=$1
    local url="${_g_ver[FLAKE_REPO_URL]:-}"
    local owner="${_g_ver[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_ver[GIT_ACCESS_REPO]:-}"

    nds_git_keys_load_all || true
    if nds_git_probe_access "$url"; then
        success "Git access confirmed for ${owner}/${repo}."
        nds_git_access_mark_verified
        _g_ver[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi
    return 1
}

# Description: True when cfg requests a GH-driven interactive auth path.
nds_git_access_wants_gh_ui() {
    local -n _g_gh=$1
    local method kind
    method="${_g_gh[GIT_SSH_KEY_REGISTER_METHOD]:-${_g_gh[GIT_SSH_KEY_TYPE]:-}}"
    kind="${_g_gh[GIT_AUTH_MODE]:-}"
    [[ "${method,,}" == *gh* || "${method,,}" == "account" || "${kind,,}" == "gh" \
        || "${kind,,}" == "account" ]]
}
