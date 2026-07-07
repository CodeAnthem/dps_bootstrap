#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub repo list helpers (flake closure)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Parse git URLs into owner/repo pairs for GitHub only.
# Arguments:
# - urls: <String...> Git remote URLs
# Returns:
# - <String> owner/repo lines (stdout)
nds_git_urls_to_github_repos() {
    local url parsed host owner repo
    for url in "$@"; do
        url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        nds_git_host_is_github "$host" || continue
        printf '%s/%s\n' "$owner" "$repo"
    done | sort -u
}

# Description: Fetch flake.lock from GitHub via gh API (requires active gh session).
# Arguments:
# - gh_repo: <String> owner/repo
# Returns:
# - <String> git remote URLs from the lock (stdout)
_nds_git_gh_lock_git_urls() {
    local gh_repo="$1"
    local owner repo content tmp
    local -a gh_cmd=()

    owner="${gh_repo%%/*}"
    repo="${gh_repo##*/}"
    [[ -n "$owner" && -n "$repo" ]] || return 0

    nds_git_gh_cmd gh_cmd || return 0
    content=$("${gh_cmd[@]}" api "repos/${owner}/${repo}/contents/flake.lock" \
        --jq -r '.content // empty' 2>/dev/null) || return 0
    [[ -n "$content" ]] || return 0

    tmp="$(mktemp)"
    if ! printf '%s' "$content" | tr -d '\n' | base64 -d > "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 0
    fi
    _nds_flake_lock_ssh_urls "$tmp"
    rm -f "$tmp"
}

# Description: Merge root repo(s) with GitHub repos referenced in their flake.lock.
# Arguments:
# - repos: <String...> owner/repo seeds
# Returns:
# - <String> Deduped owner/repo lines (stdout)
nds_git_gh_expand_github_repos() {
    local -a seeds=("$@")
    local -a out=()
    local -a gh_repos=()
    local gh_repo url

    out=("${seeds[@]}")
    for gh_repo in "${seeds[@]}"; do
        [[ -n "$gh_repo" ]] || continue
        mapfile -t gh_repos < <(nds_git_urls_to_github_repos "git@github.com:${gh_repo}.git")
        mapfile -t out < <(printf '%s\n' "${out[@]}" "${gh_repos[@]}")
        while IFS= read -r url; do
            [[ -n "$url" ]] || continue
            mapfile -t gh_repos < <(nds_git_urls_to_github_repos "$url")
            mapfile -t out < <(printf '%s\n' "${out[@]}" "${gh_repos[@]}")
        done < <(_nds_git_gh_lock_git_urls "$gh_repo")
    done
    printf '%s\n' "${out[@]}" | awk 'NF' | sort -u
}
