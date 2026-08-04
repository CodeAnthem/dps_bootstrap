#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git per-repo access state (URL-keyed maps)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-04
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

# Description: Read a URL-keyed access map value (method | key_path | key_kind).
nds_git_access_get() {
    local map="$1" url
    url="$(nds_git_normalize_url "$2")" || return 1
    case "$map" in
        method)   printf '%s\n' "${NDS_GIT_METHOD[$url]:-}" ;;
        key_path) printf '%s\n' "${NDS_GIT_KEY_PATH[$url]:-}" ;;
        key_kind) printf '%s\n' "${NDS_GIT_KEY_KIND[$url]:-}" ;;
        *) return 1 ;;
    esac
}

# Description: Write a URL-keyed access map value (method | key_path | key_kind).
nds_git_access_set() {
    local map="$1" value="$3" url
    url="$(nds_git_normalize_url "$2")" || return 1
    case "$map" in
        method)   NDS_GIT_METHOD["$url"]="$value" ;;
        key_path) NDS_GIT_KEY_PATH["$url"]="$value" ;;
        key_kind) NDS_GIT_KEY_KIND["$url"]="$value" ;;
        *) return 1 ;;
    esac
}

# Description: Apply a stored map entry — register key path if present and probe.
nds_git_access_apply_map() {
    local url="$1" norm path
    norm="$(nds_git_normalize_url "$url")" || return 1
    path="${NDS_GIT_KEY_PATH[$norm]:-}"

    [[ -n "${NDS_GIT_METHOD[$norm]:-}" || -n "$path" ]] || return 1

    if [[ -n "$path" && -f "$path" ]]; then
        nds_git_keys_register "$path" || return 1
        nds_git_probe_access "$norm"
        return $?
    fi
    return 1
}
