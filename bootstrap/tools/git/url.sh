#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git URL utilities
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
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

# Description: Provider-specific URL where a read-only deploy key is added.
_nds_git_keys_url() {
    local host="$1" owner="$2" repo="$3"
    case "$host" in
        github.com|*.github.com) printf 'https://%s/%s/%s/settings/keys/new\n' "$host" "$owner" "$repo" ;;
        *gitlab*) printf 'https://%s/%s/%s/-/settings/repository  (Deploy keys)\n' "$host" "$owner" "$repo" ;;
        *) printf 'add a read-only deploy key for %s/%s on %s\n' "$owner" "$repo" "$host" ;;
    esac
}

# Description: Normalize a remote URL to SSH for git operations.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> SSH URL on stdout (unchanged when already SSH or unparseable)
_nds_git_ssh_url() {
    local url="$1" parsed host owner repo
    case "$url" in
        git@*|ssh://*) printf '%s\n' "$url"; return 0 ;;
    esac
    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        _nds_git_to_ssh "$host" "$owner" "$repo"
    else
        printf '%s\n' "$url"
    fi
}
