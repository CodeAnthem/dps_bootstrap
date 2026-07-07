#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub deploy key registration (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Add read-only deploy key to a repository via gh API.
# Arguments:
# - pub_file: <String> Public key path
# - owner:    <String> Repository owner
# - repo:     <String> Repository name
# - title:    <String> Key title on GitHub
# Returns:
# - <Bool> 0 on success
nds_git_gh_register_deploy_key() {
    local pub_file="$1" owner="$2" repo="$3" title="$4"
    local key_body payload err rc
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    [[ -n "$owner" && -n "$repo" && -n "$title" ]] || return 1
    nds_git_gh_cmd gh_cmd || return 1

    key_body="$(tr -d '\n' < "$pub_file")"
    payload=$(printf '{"title":"%s","key":"%s","read_only":true}' "$title" "$key_body")

    err=$("${gh_cmd[@]}" api --method POST "repos/${owner}/${repo}/keys" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --input - <<< "$payload" 2>&1) || rc=$?
    if [[ "${rc:-0}" -ne 0 ]]; then
        debug "gh api POST repos/${owner}/${repo}/keys failed: ${err}"
        if grep -qi 'already exists\|key is already in use' <<< "$err"; then
            nds_install_log "git: deploy key may already exist on ${owner}/${repo}"
            return 0
        fi
        return 1
    fi
    nds_install_log "git: deploy key added read-only on ${owner}/${repo} (${title})"
    return 0
}

# Description: Register deploy key for one repo (generate session key if needed).
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# Returns:
# - <Bool> 0 on success
nds_git_gh_register_deploy_for_repo() {
    local owner="$1" repo="$2"
    local pub title

    nds_git_deploy_key_generate "$owner" "$repo" || return 1
    pub="$(nds_git_deploy_key_pubkey_path "$owner" "$repo")"
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    nds_git_gh_register_deploy_key "$pub" "$owner" "$repo" "$title" || return 1
    return 0
}
