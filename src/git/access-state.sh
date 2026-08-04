#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git per-repo access state (URL-keyed maps)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-07-31
# Description:   NDS_GIT_METHOD / KEY_PATH / KEY_KIND keyed by normalized SSH URL
# ==================================================================================================

# Description: Normalize a git URL to canonical SSH form for map keys.
# Arguments:
# - url: <String> Any git URL
# Returns:
# - <String> Normalized SSH URL (stdout)
nds_git_normalize_url() {
    local url="$1" parsed host owner repo
    [[ -n "$url" ]] || return 1
    if parsed=$(_git_parse "$url" 2>/dev/null); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        _git_to_ssh "$host" "$owner" "$repo"
        return 0
    fi
    _git_ssh_url "$url" 2>/dev/null || printf '%s\n' "$url"
}

# Description: Get METHOD for a repo URL (gh|account|deploy|import).
nds_git_access_get_method() {
    local url
    url="$(nds_git_normalize_url "$1")" || return 1
    printf '%s\n' "${NDS_GIT_METHOD[$url]:-}"
}

nds_git_access_set_method() {
    local url method="$2"
    url="$(nds_git_normalize_url "$1")" || return 1
    NDS_GIT_METHOD["$url"]="$method"
}

nds_git_access_get_key_path() {
    local url
    url="$(nds_git_normalize_url "$1")" || return 1
    printf '%s\n' "${NDS_GIT_KEY_PATH[$url]:-}"
}

nds_git_access_set_key_path() {
    local url path="$2"
    url="$(nds_git_normalize_url "$1")" || return 1
    NDS_GIT_KEY_PATH["$url"]="$path"
}

nds_git_access_get_key_kind() {
    local url
    url="$(nds_git_normalize_url "$1")" || return 1
    printf '%s\n' "${NDS_GIT_KEY_KIND[$url]:-}"
}

nds_git_access_set_key_kind() {
    local url kind="$2"
    url="$(nds_git_normalize_url "$1")" || return 1
    NDS_GIT_KEY_KIND["$url"]="$kind"
}

# Description: Apply a stored map entry — register key path if present and probe.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when access works
nds_git_access_apply_map() {
    local url="$1" norm method path
    norm="$(nds_git_normalize_url "$url")" || return 1
    method="${NDS_GIT_METHOD[$norm]:-}"
    path="${NDS_GIT_KEY_PATH[$norm]:-}"

    [[ -n "$method" || -n "$path" ]] || return 1

    if [[ -n "$path" && -f "$path" ]]; then
        nds_git_keys_register "$path" || return 1
        nds_git_probe_access "$norm"
        return $?
    fi
    return 1
}
