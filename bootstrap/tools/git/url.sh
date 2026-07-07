#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git URL utilities
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Parse and normalize git remote URLs (no config store access)
# ==================================================================================================

# Description: Split a git URL into host, owner, repo (repo without .git suffix).
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> "host<TAB>owner<TAB>repo" on stdout, non-zero when unparseable
_nds_git_parse() {
    local url="$1" host path rest
    case "$url" in
        *://*)
            rest="${url#*://}"
            rest="${rest#*@}"
            host="${rest%%/*}"
            path="${rest#*/}"
            ;;
        *@*:*)
            rest="${url#*@}"
            host="${rest%%:*}"
            path="${rest#*:}"
            ;;
        *)
            return 1
            ;;
    esac
    path="${path%.git}"
    path="${path%/}"
    [[ "$path" == */* ]] || return 1
    printf '%s\t%s\t%s\n' "$host" "${path%/*}" "${path##*/}"
}

_nds_git_to_ssh() { printf 'git@%s:%s/%s.git\n' "$1" "$2" "$3"; }

# Description: Lowercase filesystem slug from git remote owner (org or user).
# Reads FLAKE_REPO_URL from configurator when no URL argument is passed.
# Arguments:
# - url: <String|optional> Git remote URL
# Returns:
# - <String> slug on stdout (e.g. codeanthem), or "unknown"
nds_git_owner_slug() {
    local url="${1:-}"
    local parsed host owner repo slug

    if [[ -z "$url" ]]; then
        if declare -f nds_configurator_config_get &>/dev/null; then
            url="$(nds_configurator_config_get FLAKE_REPO_URL 2>/dev/null || true)"
        fi
        [[ -z "$url" ]] && url="$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)"
    fi
    [[ -n "$url" ]] || { printf 'unknown\n'; return 0; }

    url=$(_nds_git_ssh_url "$url")
    parsed=$(_nds_git_parse "$url") || { printf 'unknown\n'; return 0; }
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    [[ -n "$owner" ]] || { printf 'unknown\n'; return 0; }

    slug=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
    slug=$(printf '%s' "$slug" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
    [[ -n "$slug" ]] && printf '%s\n' "$slug" || printf 'unknown\n'
}

# Description: Normalize a remote URL to canonical git@host:owner/repo.git for git operations.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> SSH URL on stdout (unchanged when unparseable)
_nds_git_ssh_url() {
    local url="$1" parsed host owner repo

    case "$url" in
        git+ssh://*) url="${url#git+ssh://}" ;;
    esac
    case "$url" in
        *@*) ;;
        */*)
            url="git@${url}"
            ;;
    esac
    case "$url" in
        git@*:*/*) ;;
        git@*/*)
            local rest="${url#git@}"
            url="git@${rest%%/*}:${rest#*/}"
            ;;
    esac

    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        _nds_git_to_ssh "$host" "$owner" "$repo"
        return 0
    fi

    printf '%s\n' "$url"
}
