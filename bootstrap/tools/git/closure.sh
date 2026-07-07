#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake git closure access
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Scan flake.lock / flake.nix and verify SSH access to every git input
# ==================================================================================================

# Description: Extract git SSH remote URLs from flake.lock (git+ssh, ssh, and type git nodes).
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> URLs (stdout, one per line)
_nds_flake_lock_ssh_urls() {
    local lock_file="$1"
    [[ -f "$lock_file" ]] || return 0
    {
        grep -oE '(git\+ssh|ssh)://[^"[:space:]]+' "$lock_file" 2>/dev/null || true
        grep -oE '"url": "(git\+ssh|ssh)://[^"]+"' "$lock_file" 2>/dev/null \
            | sed -e 's/^"url": "//' -e 's/"$//' || true
    } | sort -u
}

# Description: Collect unique git remote URLs from a flake directory.
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

# Description: Fetch flake.lock via sparse git clone (uses session deploy keys).
# Arguments:
# - ssh_url:   <String> Normalized SSH URL
# - lock_dest: <String> Destination file
# Returns:
# - <Bool> 0 on success
_nds_git_fetch_flake_lock_git_sparse() {
    local ssh_url="$1" lock_dest="$2"
    local -a envv=() tmp

    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env)
    tmp="$(mktemp -d)"
    if env "${envv[@]}" git clone --depth 1 --filter=blob:none --sparse "$ssh_url" "$tmp/repo" 2>/dev/null; then
        if (cd "$tmp/repo" && git sparse-checkout set flake.lock 2>/dev/null \
            && [[ -f flake.lock ]]); then
            cp "$tmp/repo/flake.lock" "$lock_dest"
            rm -rf "$tmp"
            [[ -s "$lock_dest" ]] && return 0
        fi
    fi
    rm -rf "$tmp"
    return 1
}

# Description: Decode base64 from GitHub API content field into a file.
# Arguments:
# - b64:  <String> Base64 payload
# - dest: <String> Output file
# Returns:
# - <Bool> 0 on success
_nds_git_b64_decode_to_file() {
    local b64="$1" dest="$2"
    if printf '%s' "$b64" | tr -d '\n' | base64 -d > "$dest" 2>/dev/null \
        && [[ -s "$dest" ]]; then
        return 0
    fi
    if command -v openssl &>/dev/null \
        && printf '%s' "$b64" | tr -d '\n' | openssl base64 -d -A > "$dest" 2>/dev/null \
        && [[ -s "$dest" ]]; then
        return 0
    fi
    return 1
}

# Description: Fetch flake.lock for a remote root URL without cloning the full repo.
# Arguments:
# - root_url:  <String> Root flake git URL
# - lock_dest: <String> Destination file path
# Returns:
# - <Bool> 0 on success
nds_git_fetch_flake_lock() {
    local root_url="$1" lock_dest="$2"
    local ssh_url parsed host owner repo content tmp
    local -a gh_cmd=() envv=()

    ssh_url=$(_nds_git_ssh_url "$root_url")
    mkdir -p "$(dirname "$lock_dest")"

    if _nds_git_fetch_flake_lock_git_sparse "$ssh_url" "$lock_dest"; then
        nds_install_log "git: flake.lock via sparse clone (${ssh_url})"
        return 0
    fi

    if parsed=$(_nds_git_parse "$ssh_url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if nds_git_host_is_github "$host" && nds_git_gh_session_active 2>/dev/null; then
            nds_git_gh_cmd gh_cmd || true
            if [[ ${#gh_cmd[@]} -gt 0 ]]; then
                content=$("${gh_cmd[@]}" api "repos/${owner}/${repo}/contents/flake.lock" \
                    --jq -r '.content // empty' 2>/dev/null) || content=""
                if [[ -n "$content" ]] && _nds_git_b64_decode_to_file "$content" "$lock_dest"; then
                    nds_install_log "git: flake.lock via gh API (${owner}/${repo})"
                    return 0
                fi
            fi
        fi
    fi

    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env)
    if env "${envv[@]}" git archive --remote="$ssh_url" HEAD flake.lock 2>/dev/null \
        | tar -xO > "$lock_dest" 2>/dev/null \
        && [[ -s "$lock_dest" ]]; then
        nds_install_log "git: flake.lock via git archive (${ssh_url})"
        return 0
    fi

    debug "flake.lock fetch failed for ${ssh_url}"
    return 1
}

# Description: Collect git input URLs from a remote root flake (flake.lock only, no full clone).
# Arguments:
# - root_url: <String> Root flake git URL
# Returns:
# - <String> Newline-separated SSH-normalized URLs (stdout)
_nds_flake_collect_git_remote_urls_from_root() {
    local root_url="$1"
    local lock_file="${NDS_RUNTIME_DIR:-/tmp}/flake_lock_probe/flake.lock"
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

    if nds_git_fetch_flake_lock "$root_url" "$lock_file"; then
        export NDS_GIT_FLAKE_LOCK_FILE="$lock_file"
        while IFS= read -r url; do
            _nds_flake_add_git_url "$url"
        done < <(_nds_flake_lock_ssh_urls "$lock_file")
    else
        warn "Could not fetch flake.lock — only checking the root repository."
        nds_install_log "git: flake.lock fetch failed for closure scan"
    fi
}

# Description: Probe SSH access to every git remote referenced by a flake closure.
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
