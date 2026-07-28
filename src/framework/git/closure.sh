#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake git closure access
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Scan flake.lock / flake.nix and verify SSH access to every git input
# ==================================================================================================

# Description: Session directory for the root flake shallow clone.
_nds_flake_probe_repo_dir() {
    printf '%s/flake_probe/repo\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Shallow-clone root flake once per session (closure, disko, install staging).
# Arguments:
# - root_url: <String> Root flake git URL
# Returns:
# - <Bool> 0 on success
nds_git_clone_flake_probe() {
    local root_url="$1"
    local clone_dir norm_url err rc=0

    clone_dir="$(_nds_flake_probe_repo_dir)"
    norm_url=$(_nds_git_ssh_url "$root_url")

    if [[ -f "${NDS_FLAKE_PROBE_REPO:-}/flake.nix" \
        && "${NDS_FLAKE_PROBE_REPO_URL:-}" == "$norm_url" ]]; then
        return 0
    fi
    if [[ -f "${clone_dir}/flake.nix" && "${NDS_FLAKE_PROBE_REPO_URL:-}" == "$norm_url" ]]; then
        NDS_FLAKE_PROBE_REPO="$clone_dir"
        export NDS_FLAKE_PROBE_REPO NDS_FLAKE_PROBE_REPO_URL
        return 0
    fi

    mkdir -p "$(dirname "$clone_dir")"
    rm -rf "$clone_dir"

    err=$(nds_git_clone "$root_url" "$clone_dir" 1 2>&1) || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        debug "flake probe clone failed: ${err}"
        rm -rf "$clone_dir"
        return 1
    fi
    if [[ ! -f "${clone_dir}/flake.nix" ]]; then
        debug "flake.nix missing after clone of ${root_url}"
        rm -rf "$clone_dir"
        return 1
    fi

    NDS_FLAKE_PROBE_REPO="$clone_dir"
    NDS_FLAKE_PROBE_REPO_URL="$norm_url"
    export NDS_FLAKE_PROBE_REPO NDS_FLAKE_PROBE_REPO_URL
    nds_install_log "git: flake repository cloned (${norm_url})"
    return 0
}

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

# Description: Decode base64 from GitHub API content field into a file.
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

# Description: Fetch flake.lock via gh API when clone is unavailable.
# Arguments:
# - root_url:  <String> Root flake git URL
# - lock_dest: <String> Destination file path
# Returns:
# - <Bool> 0 on success
_nds_git_fetch_flake_lock_via_api() {
    local root_url="$1" lock_dest="$2"
    local ssh_url parsed host owner repo content
    local -a gh_cmd=()

    ssh_url=$(_nds_git_ssh_url "$root_url")
    parsed=$(_nds_git_parse "$ssh_url") || return 1
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    nds_git_host_is_github "$host" || return 1
    nds_git_gh_session_active 2>/dev/null || return 1
    nds_git_gh_cmd gh_cmd || return 1
    [[ ${#gh_cmd[@]} -gt 0 ]] || return 1

    content=$("${gh_cmd[@]}" api "repos/${owner}/${repo}/contents/flake.lock" \
        --jq -r '.content // empty' 2>/dev/null) || content=""
    [[ -n "$content" ]] || return 1
    mkdir -p "$(dirname "$lock_dest")"
    if _nds_git_b64_decode_to_file "$content" "$lock_dest"; then
        nds_install_log "git: flake.lock via gh API (${owner}/${repo})"
        return 0
    fi
    return 1
}

# Description: Collect git input URLs from a remote root flake.
_nds_flake_collect_git_remote_urls_from_root() {
    local root_url="$1"
    local probe_dir lock_file
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

    probe_dir="${NDS_FLAKE_PROBE_REPO:-$(_nds_flake_probe_repo_dir)}"
    if [[ -f "${probe_dir}/flake.nix" ]]; then
        export NDS_GIT_FLAKE_LOCK_FILE="${probe_dir}/flake.lock"
        _nds_flake_collect_git_remote_urls "$probe_dir" "$root_url"
        return 0
    fi

    lock_file="${NDS_RUNTIME_DIR:-/tmp}/flake_probe/flake.lock.api"
    if _nds_git_fetch_flake_lock_via_api "$root_url" "$lock_file"; then
        export NDS_GIT_FLAKE_LOCK_FILE="$lock_file"
        [[ -n "$root_url" ]] && _nds_flake_add_git_url "$root_url"
        while IFS= read -r url; do
            _nds_flake_add_git_url "$url"
        done < <(_nds_flake_lock_ssh_urls "$lock_file")
        return 0
    fi

    warn "Could not clone flake repository — only checking the root repository."
    nds_install_log "git: flake probe clone failed for closure scan"
    [[ -n "$root_url" ]] && _nds_flake_add_git_url "$root_url"
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

# Compatibility alias — callers should use nds_git_clone_flake_probe.
nds_git_fetch_flake_lock() {
    local root_url="$1" lock_dest="$2"
    nds_git_clone_flake_probe "$root_url" || return 1
    [[ -f "${NDS_FLAKE_PROBE_REPO}/flake.lock" ]] || return 1
    cp "${NDS_FLAKE_PROBE_REPO}/flake.lock" "$lock_dest"
}
