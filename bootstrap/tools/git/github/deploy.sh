#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub deploy key registration (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-08
# ==================================================================================================

# Description: List deploy key ids on a repo that match a title.
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# - title: <String> Deploy key title
# Returns:
# - <String> key ids (stdout, one per line)
_nds_git_gh_deploy_key_ids_by_title() {
    local owner="$1" repo="$2" title="$3"
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" api "repos/${owner}/${repo}/keys" \
        --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null
}

# Description: Resolve deploy-key title collision on one repository.
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# - title: <Nameref> Desired key title (may be changed for alternate)
# Returns:
# - <Bool> 0 when a title strategy is chosen
_nds_git_gh_deploy_resolve_title_collision() {
    local owner="$1" repo="$2"
    local -n _title=$3
    local prompt choice suffix n=2

    prompt="Deploy key title \"${_title}\" already exists on ${owner}/${repo} with a different public key"
    nds_cfg_ask_choice GIT_SSH_KEY_TITLE_COLLISION \
        "$prompt" \
        "overwrite|alternate|cancel" \
        "overwrite=Remove the old key and register this one|alternate=Use an alternate title (${_title}-2)|cancel=Cancel — choose a different approach" \
        "cancel"
    choice="$(nds_cfg_get GIT_SSH_KEY_TITLE_COLLISION)"
    case "$choice" in
        overwrite) return 0 ;;
        alternate)
            while :; do
                suffix="${_title}-${n}"
                if [[ -z "$(_nds_git_gh_deploy_key_ids_by_title "$owner" "$repo" "$suffix")" ]]; then
                    _title="$suffix"
                    return 0
                fi
                n=$((n + 1))
                [[ "$n" -gt 50 ]] && return 1
            done
            ;;
        *) return 1 ;;
    esac
}

# Description: True when the public key is already a deploy key on the repository.
nds_git_gh_deploy_pubkey_on_repo() {
    local owner="$1" repo="$2" pub_file="$3"
    local key_body
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    nds_git_gh_cmd gh_cmd || return 1
    key_body="$(awk '{print $2}' "$pub_file")"
    [[ -n "$key_body" ]] || return 1
    "${gh_cmd[@]}" api "repos/${owner}/${repo}/keys" --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_body"
}

# Description: Delete one deploy key from a repository.
_nds_git_gh_deploy_key_delete() {
    local owner="$1" repo="$2" id="$3"
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" api --method DELETE "repos/${owner}/${repo}/keys/${id}" 2>/dev/null
}

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
    local key_body payload err rc id
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    [[ -n "$owner" && -n "$repo" && -n "$title" ]] || return 1
    nds_git_gh_cmd gh_cmd || return 1

    if [[ -n "$(_nds_git_gh_deploy_key_ids_by_title "$owner" "$repo" "$title")" ]]; then
        _nds_git_gh_deploy_resolve_title_collision "$owner" "$repo" title || return 1
    fi

    if nds_git_gh_deploy_pubkey_on_repo "$owner" "$repo" "$pub_file"; then
        nds_install_log "git: deploy key already on ${owner}/${repo} (${title})"
        nds_git_gh_session_mark_scopes_ok
        return 0
    fi

    if [[ "$(nds_cfg_get GIT_SSH_KEY_TITLE_COLLISION 2>/dev/null)" == "overwrite" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            _nds_git_gh_deploy_key_delete "$owner" "$repo" "$id" || true
        done < <(_nds_git_gh_deploy_key_ids_by_title "$owner" "$repo" "$title")
        if nds_git_gh_deploy_pubkey_on_repo "$owner" "$repo" "$pub_file"; then
            nds_install_log "git: deploy key already on ${owner}/${repo} (${title})"
            nds_git_gh_session_mark_scopes_ok
            return 0
        fi
    fi

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
            nds_git_gh_session_mark_scopes_ok
            return 0
        fi
        return 1
    fi
    nds_install_log "git: deploy key added read-only on ${owner}/${repo} (${title})"
    nds_git_gh_session_mark_scopes_ok
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
    local pub title key_path

    key_path="$(nds_git_deploy_key_path "$owner" "$repo")"
    pub="${key_path}.pub"
    if [[ ! -f "$pub" ]]; then
        nds_git_deploy_key_generate "$owner" "$repo" || return 1
    else
        nds_git_keys_register "$key_path" || true
    fi
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    nds_git_gh_register_deploy_key "$pub" "$owner" "$repo" "$title" || return 1
    return 0
}
