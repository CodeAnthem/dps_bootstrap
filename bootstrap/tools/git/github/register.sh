#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub account SSH key registration (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Normalize public key to "type body" for comparison.
# Arguments:
# - pub_file: <String> Public key path
# Returns:
# - <String> key line (stdout)
_nds_git_gh_pubkey_line() {
    local pub_file="$1"
    awk '{print $1" "$2}' "$pub_file"
}

# Description: True when the public key is on the logged-in GitHub user account.
# Arguments:
# - pub_file: <String> Public key path
# Returns:
# - <Bool> 0 when key is present
nds_git_gh_pubkey_on_user() {
    local pub_file="$1"
    local key_line
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    key_line="$(_nds_git_gh_pubkey_line "$pub_file")"
    "${gh_cmd[@]}" ssh-key list --json key --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_line"
}

# Description: List account SSH key ids that match a title.
# Arguments:
# - title: <String> Key title
# Returns:
# - <String> key ids (stdout, one per line)
_nds_git_gh_user_key_ids_by_title() {
    local title="$1"
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" ssh-key list --json id,title --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null
}

# Description: Delete one account SSH key by id.
# Arguments:
# - id: <String> GitHub key id
# Returns:
# - <Bool> 0 on success
_nds_git_gh_user_key_delete() {
    local id="$1"
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" ssh-key delete "$id" 2>/dev/null
}

# Description: Resolve title collision — overwrite, alternate suffix, or abort.
# Arguments:
# - title: <Nameref> Key title (may be updated)
# Returns:
# - <Bool> 0 when user chose overwrite or alternate, 1 when aborted
_nds_git_gh_resolve_title_collision() {
    local -n _title=$1
    local choice suffix n=2

    nds_cfg_ask_choice GIT_SSH_KEY_TITLE_COLLISION \
        "SSH key title \"${_title}\" already exists on GitHub with a different public key" \
        "overwrite|alternate|cancel" \
        "overwrite=Remove the old key and register this one|alternate=Use an alternate title (${_title}-2)|cancel=Cancel — choose a different approach" \
        "cancel"
    choice="$(nds_cfg_get GIT_SSH_KEY_TITLE_COLLISION)"
    case "$choice" in
        overwrite) return 0 ;;
        alternate)
            while :; do
                suffix="${_title}-${n}"
                if [[ -z "$(_nds_git_gh_user_key_ids_by_title "$suffix")" ]]; then
                    _title="$suffix"
                    return 0
                fi
                n=$((n + 1))
                [[ "$n" -gt 20 ]] && return 1
            done
            ;;
        *) return 1 ;;
    esac
}

# Description: Add read-only account SSH key via gh API.
# Arguments:
# - pub_file: <String> Public key path
# - title:    <String> Key title
# Returns:
# - <Bool> 0 on success
_nds_git_gh_api_add_readonly_key() {
    local pub_file="$1" title="$2"
    local key_body err rc
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    key_body="$(tr -d '\n' < "$pub_file")"
    err=$("${gh_cmd[@]}" api -X POST user/keys \
        -f "title=${title}" \
        -f "key=${key_body}" \
        -f "read_only=true" 2>&1) || rc=$?
    [[ "${rc:-0}" -eq 0 ]]
}

# Description: Register session public key on the GitHub account (read-only).
# Arguments:
# - pub_file: <String> Public key path
# - title:    <String> Key title
# Returns:
# - <Bool> 0 on success
nds_git_gh_register_account_key() {
    local pub_file="$1"
    local title="$2"
    local id err rc
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    nds_git_gh_cmd gh_cmd || return 1

    if nds_git_gh_pubkey_on_user "$pub_file"; then
        nds_install_log "git: account SSH key already present (${title})"
        return 0
    fi

    if [[ -n "$(_nds_git_gh_user_key_ids_by_title "$title")" ]]; then
        _nds_git_gh_resolve_title_collision title || return 1
        if nds_git_gh_pubkey_on_user "$pub_file"; then
            return 0
        fi
    fi

    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if [[ "$(nds_cfg_get GIT_SSH_KEY_TITLE_COLLISION 2>/dev/null)" == "overwrite" ]]; then
            _nds_git_gh_user_key_delete "$id" || true
        fi
    done < <(_nds_git_gh_user_key_ids_by_title "$title")

    if _nds_git_gh_api_add_readonly_key "$pub_file" "$title"; then
        nds_install_log "git: account SSH key added read-only (${title})"
        return 0
    fi

    err=$("${gh_cmd[@]}" ssh-key add "$pub_file" -t "$title" 2>&1) || rc=$?
    if [[ "${rc:-0}" -eq 0 ]]; then
        nds_install_log "git: account SSH key added via gh ssh-key add (${title})"
        return 0
    fi

    if nds_git_gh_pubkey_on_user "$pub_file"; then
        return 0
    fi

    warn "Could not add SSH key to GitHub account"
    nds_ui_i "  ${err}"
    return 1
}

# Description: Register account SSH key for GitHub repos in scope (expands flake.lock).
# Arguments:
# - pub_file: <String> Public key path
# - repos:    <String...> owner/repo seeds
# Returns:
# - <Bool> 0 on success
nds_git_gh_register_for_repos() {
    local pub_file="$1"
    shift
    local -a repos=("$@")
    local key_title

    [[ -f "$pub_file" ]] || return 1
    [[ ${#repos[@]} -gt 0 ]] || return 1
    nds_git_gh_available || return 1

    key_title="$(nds_git_ssh_key_title)"
    nds_git_key_load "$(nds_git_session_key_path)" || true

    mapfile -t repos < <(nds_git_gh_expand_github_repos "${repos[@]}")
    nds_install_log "git: registering account SSH key for ${#repos[@]} repo(s)"

    nds_git_gh_register_account_key "$pub_file" "$key_title"
}
