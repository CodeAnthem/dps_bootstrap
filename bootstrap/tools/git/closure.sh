#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake git closure access
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
# Description:   Scan flake.lock / flake.nix and verify SSH access to every git input
# ==================================================================================================

# Description: Extract git+ssh:// and ssh:// URLs from flake.lock.
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> Newline-separated URLs (stdout)
_nds_flake_lock_ssh_urls() {
    local lock_file="$1"
    [[ -f "$lock_file" ]] || return 0
    grep -oE '(git\+ssh|ssh)://[^"]+' "$lock_file" 2>/dev/null | sort -u || true
}

# Description: Collect unique git remote URLs from a flake (lock, flake.nix, root URL).
# Arguments:
# - flake_root: <String> Flake directory
# - root_url:   <String|optional> Root flake git URL
# Returns:
# - <String> Newline-separated SSH-normalized clone URLs (stdout)
_nds_flake_collect_git_remote_urls() {
    local flake_root="$1" root_url="${2:-}"
    local lock="${flake_root}/flake.lock"
    local flake_nix="${flake_root}/flake.nix"
    declare -A seen=()
    local url norm

    _nds_flake_add_git_url() {
        local u="$1"
        [[ -n "$u" ]] || return 0
        norm=$(_nds_git_ssh_url "$u")
        [[ -n "$norm" ]] || return 0
        [[ -n "${seen[$norm]:-}" ]] && return 0
        seen[$norm]=1
        printf '%s\n' "$norm"
    }

    [[ -n "$root_url" ]] && _nds_flake_add_git_url "$root_url"

    if [[ -f "$lock" ]]; then
        while IFS= read -r url; do
            _nds_flake_add_git_url "$url"
        done < <(_nds_flake_lock_ssh_urls "$lock")
    fi

    if [[ -f "$flake_nix" ]]; then
        while IFS= read -r url; do
            _nds_flake_add_git_url "$url"
        done < <(grep -oE 'git\+ssh://[^"[:space:]]+|git@[^"[:space:]]+\.git' "$flake_nix" 2>/dev/null \
            | sort -u || true)
    fi
}

# Description: Probe SSH access to every git remote referenced by a flake closure.
# Arguments:
# - flake_root: <String> Probe or staged flake directory
# - root_url:   <String|optional> Root flake git URL
# - on_missing: <Function|optional> Callback(host owner repo ssh_url) for each failed repo
# Returns:
# - <Bool> 0 when all reachable
nds_git_probe_flake_closure() {
    local flake_root="$1" root_url="${2:-}"
    local -a urls=() failed=()
    local url

    [[ -d "$flake_root" ]] || { error "Flake root not found: $flake_root"; return 1; }

    mapfile -t urls < <(_nds_flake_collect_git_remote_urls "$flake_root" "$root_url")
    [[ ${#urls[@]} -gt 0 ]] || return 0

    for url in "${urls[@]}"; do
        if nds_git_probe_access "$url"; then
            debug "Git access OK: $url"
        else
            failed+=("$url")
        fi
    done

    [[ ${#failed[@]} -eq 0 ]]
}
