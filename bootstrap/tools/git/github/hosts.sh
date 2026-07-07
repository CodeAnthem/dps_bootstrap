#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub host detection and account SSH key URLs
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: True when host is GitHub.
# Arguments:
# - host: <String> Parsed git host
# Returns:
# - <Bool> 0 when GitHub
nds_git_host_is_github() {
    local host="$1"
    [[ "$host" == github.com || "$host" == *.github.com ]]
}

# Description: True when every URL resolves to a GitHub host.
# Arguments:
# - urls: <String...> Git remote URLs
# Returns:
# - <Bool> 0 when all URLs are github.com
nds_git_urls_all_github() {
    local url ssh_url parsed host owner repo
    for url in "$@"; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || return 1
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        nds_git_host_is_github "$host" || return 1
    done
    return 0
}

# Description: Account SSH key registration URL for a git host.
# Arguments:
# - host: <String> Parsed git host
# Returns:
# - <String> HTTPS URL (stdout)
nds_git_account_ssh_register_url() {
    local host="$1"
    case "$host" in
        github.com|*.github.com)
            printf 'https://github.com/settings/ssh/new\n'
            ;;
        *gitlab*)
            printf 'https://%s/-/profile/keys\n' "$host"
            ;;
        *)
            printf 'https://%s (account SSH keys in your profile settings)\n' "$host"
            ;;
    esac
}

# Description: Primary git host from the first parseable URL.
# Arguments:
# - urls: <String...> Git remote URLs
# Returns:
# - <String> host name (stdout), empty when unknown
nds_git_primary_host_from_urls() {
    local url ssh_url parsed host owner repo
    for url in "$@"; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_ssh_url "$url")
        if parsed=$(_nds_git_parse "$ssh_url"); then
            IFS=$'\t' read -r host owner repo <<< "$parsed"
            printf '%s\n' "$host"
            return 0
        fi
    done
    printf '\n'
}
