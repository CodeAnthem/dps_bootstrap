#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard new-key and registration menus
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Ask gh CLI vs manual registration.
# Returns:
# - <String> gh or manual (stdout)
nds_git_wizard_ask_register_method() {
    local choice host existing

    existing="$(nds_cfg_get GIT_SSH_KEY_REGISTER_METHOD 2>/dev/null || true)"
    if [[ -n "$existing" ]]; then
        [[ "$existing" == "gh" ]] && printf 'gh\n' || printf 'manual\n'
        return 0
    fi

    if ! nds_git_gh_available 2>/dev/null; then
        if ! command -v gh &>/dev/null; then
            nds_git_gh_prefetch 2>/dev/null || true
        fi
    fi
    if ! nds_git_gh_available 2>/dev/null; then
        printf 'manual\n'
        return 0
    fi

    nds_cfg_ask_numbered_choice GIT_SSH_KEY_REGISTER_METHOD \
        "gh|manual" \
        "gh=Use gh CLI (device login on this ISO)|manual=Show key and register on github.com yourself" \
        "gh"
    choice="$(nds_cfg_get GIT_SSH_KEY_REGISTER_METHOD)"
    [[ "$choice" == "gh" ]] && printf 'gh\n' || printf 'manual\n'
}

# Description: Resolve git host for owner/repo from URL list.
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# - urls:  <String...> Git URLs to search
# Returns:
# - <String> host name (stdout)
_nds_git_host_for_owner_repo() {
    local want_owner="$1" want_repo="$2"
    shift 2
    local url ssh_url parsed host owner repo

    for url in "$@"; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$owner" == "$want_owner" && "$repo" == "$want_repo" ]]; then
            printf '%s\n' "$host"
            return 0
        fi
    done
    printf 'github.com\n'
}

# Description: Ask deploy key vs account key for new registration.
# Returns:
# - <String> deploy or account (stdout)
nds_git_wizard_ask_key_type() {
    local choice

    nds_cfg_section_title "New SSH key type"
    nds_ui_b "Deploy key: read-only, one key per repository (recommended for private repos"
    nds_ui_b "without a machine GitHub user)."
    nds_ui_b ""
    nds_ui_b "Account key: one key on a GitHub account — use a dedicated machine user"
    nds_ui_b "with read-only access to every repo (org team or collaborator)."
    nds_ui_b ""
    nds_cfg_ask_numbered_choice GIT_SSH_KEY_TYPE \
        "deploy|account" \
        "deploy=Deploy key (read-only, per repository)|account=Account key (machine user with read access)" \
        "deploy"
    choice="$(nds_cfg_get GIT_SSH_KEY_TYPE)"
    [[ "$choice" == "account" ]] && printf 'account\n' || printf 'deploy\n'
}

# Description: Register read-only deploy key for one repo (gh or manual).
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# - host:  <String> Git host
# Returns:
# - <Bool> 0 on success
nds_git_wizard_register_deploy() {
    local owner="$1" repo="$2" host="${3:-github.com}"
    local method pub register_url

    nds_git_deploy_key_generate "$owner" "$repo" || return 1
    pub="$(nds_git_deploy_key_pubkey_path "$owner" "$repo")"
    register_url="$(nds_git_deploy_key_register_url "$host" "$owner" "$repo")"
    NDS_GIT_AUTH_REGISTER_URLS=("$register_url")

    method="$(nds_git_wizard_ask_register_method)" || return 1
    if [[ "$method" == "gh" ]]; then
        nds_git_wizard_menu_gh_deploy "$owner" "$repo" || return 1
        return 0
    fi

    nds_git_wizard_menu_manual_deploy "$owner" "$repo" "$host" || return 1
    return 0
}

# Description: Register account SSH key (gh or manual, machine-user warning).
# Arguments:
# - repos: <String...> owner/repo seeds for scope display
# Returns:
# - <Bool> 0 on success
nds_git_wizard_register_account() {
    local -a repos=("$@")
    local method

    nds_ui_b ""
    nds_ui_b "Use a dedicated GitHub machine user — not your personal account."
    nds_ui_b "Grant that user read-only access to every private repository."
    nds_ui_b ""

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi
    nds_git_keys_register "$(nds_git_session_key_path)" || true
    nds_git_auth_set_mode account

    method="$(nds_git_wizard_ask_register_method)" || return 1
    if [[ "$method" == "gh" ]]; then
        nds_git_wizard_menu_gh_account "${repos[@]}" || return 1
        return 0
    fi

    nds_git_wizard_menu_manual_account || return 1
    return 0
}

# Description: New SSH key route — deploy or account, gh or manual.
# Arguments:
# - urls:  <String...> Git URLs in scope
# - repos: <String...> owner/repo pairs
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_new_key() {
    local -a urls=() repos=()
    local key_type parsing_repos=false arg owner repo host
    local ssh_url parsed

    for arg in "$@"; do
        if [[ "$arg" == "--repos" ]]; then
            parsing_repos=true
            continue
        fi
        if $parsing_repos; then
            repos+=("$arg")
        else
            urls+=("$arg")
        fi
    done

    key_type="$(nds_git_wizard_ask_key_type)" || return 1

    if [[ "$key_type" == "account" ]]; then
        [[ ${#repos[@]} -gt 0 ]] || {
            for arg in "${urls[@]}"; do
                ssh_url=$(_nds_git_ssh_url "$arg")
                parsed=$(_nds_git_parse "$ssh_url") || continue
                IFS=$'\t' read -r host owner repo <<< "$parsed"
                repos+=("${owner}/${repo}")
            done
        }
        nds_git_wizard_register_account "${repos[@]}" || return 1
        return 0
    fi

    [[ ${#repos[@]} -gt 0 ]] || {
        for arg in "${urls[@]}"; do
            ssh_url=$(_nds_git_ssh_url "$arg")
            parsed=$(_nds_git_parse "$ssh_url") || continue
            IFS=$'\t' read -r host owner repo <<< "$parsed"
            repos+=("${owner}/${repo}")
        done
    }

    for arg in "${repos[@]}"; do
        owner="${arg%%/*}"
        repo="${arg##*/}"
        [[ -n "$owner" && -n "$repo" ]] || continue
        host="$(_nds_git_host_for_owner_repo "$owner" "$repo" "${urls[@]}")"
        info "Deploy key for ${owner}/${repo}..."
        nds_git_wizard_register_deploy "$owner" "$repo" "$host" || return 1
    done
    return 0
}

# Description: Register deploy keys only for repositories still missing access.
# Arguments:
# - urls: <String...> Failed git URLs
# Returns:
# - <Bool> 0 on success
nds_git_wizard_register_deploy_for_urls() {
    local url ssh_url parsed host owner repo
    declare -A seen=()

    for url in "$@"; do
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        [[ -n "${seen[${owner}/${repo}]:-}" ]] && continue
        seen["${owner}/${repo}"]=1
        nds_git_wizard_register_deploy "$owner" "$repo" "$host" || return 1
    done
    return 0
}
