#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth wizard
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
# Description:   Multi-mode deploy-key wizard: import, generate+QR, gh register, show, retry, skip
# ==================================================================================================

# Description: Resolve gh command (host binary or nix shell).
# Sets nameref array to command prefix.
_nds_git_gh_cmd() {
    local -n _out=$1
    if command -v gh &>/dev/null; then
        _out=(gh)
    elif command -v nix &>/dev/null; then
        _out=(nix shell nixpkgs#gh -c gh)
    else
        _out=()
        return 1
    fi
    return 0
}

# Description: Parse failed git URLs into owner/repo pairs for gh deploy-key add.
# Arguments:
# - urls: <String...> SSH git URLs
# Returns:
# - <String> Newline-separated owner/repo (stdout)
_nds_git_urls_to_github_repos() {
    local url parsed host owner repo
    for url in "$@"; do
        url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        [[ "$host" == github.com || "$host" == *.github.com ]] || continue
        printf '%s/%s\n' "$owner" "$repo"
    done | sort -u
}

# Description: Temporary gh login, register read-only deploy keys, then logout.
# Arguments:
# - pub_file: <String> Public key path
# - repos:    <String...> GitHub owner/repo names
# Returns:
# - <Bool> 0 on success
nds_git_gh_register_deploy_keys() {
    local pub_file="$1"
    shift
    local -a repos=("$@") repo
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || { error "Public key missing: $pub_file"; return 1; }
    [[ ${#repos[@]} -gt 0 ]] || { warn "No GitHub repos to register"; return 1; }
    _nds_git_gh_cmd gh_cmd || {
        error "gh CLI not available (install gh or use nix on the live ISO)"
        return 1
    }

    if ! "${gh_cmd[@]}" auth status &>/dev/null; then
        info "GitHub device login (temporary — used only to add deploy keys)"
        nds_ui_b "Complete login in the browser, then return here."
        "${gh_cmd[@]}" auth login --web --git-protocol ssh --scopes "" || return 1
    fi

    for repo in "${repos[@]}"; do
        [[ -n "$repo" ]] || continue
        if "${gh_cmd[@]}" repo deploy-key add "$pub_file" -R "$repo" \
            -t "nds-$(hostname -s 2>/dev/null || echo live)" --read-only 2>/dev/null; then
            success "Deploy key registered on ${repo}"
            nds_install_log "git: gh deploy key -> ${repo}"
        else
            warn "Could not add deploy key on ${repo} (may already exist)"
        fi
    done

    "${gh_cmd[@]}" auth logout --hostname github.com 2>/dev/null || true
    nds_ui_i "GitHub session cleared."
    return 0
}

# Description: Import deploy key from path (env or prompt).
# Returns:
# - <Bool> 0 on success
nds_git_auth_wizard_import() {
    local src dest
    dest="$(nds_git_session_key_path)"

    if [[ -n "${NDS_DEPLOY_KEY_PATH:-}" && -f "$NDS_DEPLOY_KEY_PATH" ]]; then
        src="$NDS_DEPLOY_KEY_PATH"
    else
        nds_cfg_ask_path GIT_DEPLOY_KEY_IMPORT_PATH "Private deploy key path" "" true || return 1
        src="$(nds_cfg_get GIT_DEPLOY_KEY_IMPORT_PATH)"
    fi

    nds_git_key_import "$src" "$dest" || return 1
    success "Deploy key loaded from ${src}"
    return 0
}

# Description: Generate deploy key, show pubkey and QR.
# Returns:
# - <Bool> 0 on success
nds_git_auth_wizard_generate() {
    nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    nds_git_key_show_pubkey || return 1
    nds_git_key_show_qr || true
    nds_ui_b "Register this key as read-only on every private repo your flake needs."
    return 0
}

# Description: Register deploy key on GitHub repos via gh (device login).
# Arguments:
# - repos: <String...> owner/repo names
# Returns:
# - <Bool> 0 on success
nds_git_auth_wizard_gh() {
    local -a repos=("$@")
    local pub

    [[ ${#repos[@]} -gt 0 ]] || {
        warn "No GitHub repositories in scope — add keys manually"
        return 1
    }

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_auth_wizard_generate || return 1
    fi
    pub="$(nds_git_session_pubkey_path)"
    nds_git_gh_register_deploy_keys "$pub" "${repos[@]}"
}

# Description: Run one wizard step for a single repository access failure.
# Arguments:
# - host:  <String> Git host
# - owner: <String> Repo owner
# - repo:  <String> Repo name
# Returns:
# - <String> Action taken: ok|skip|retry (stdout via return: 0=retry/ok path, special cases)
nds_git_auth_wizard_step_repo() {
    local host="$1" owner="$2" repo="$3"
    local choice gh_repo

    nds_ui_b ""
    nds_cfg_ask_choice GIT_AUTH_METHOD "Deploy key setup" \
        "import|generate|gh|show|retry|skip" \
        "import=Import key (USB/path)|generate=Generate + QR|gh=Register on GitHub (device login)|show=Show public key|retry=Re-check access|skip=Skip (try anyway)" \
        "import"

    choice="$(nds_cfg_get GIT_AUTH_METHOD)"
    case "$choice" in
        import) nds_git_auth_wizard_import || return 1 ;;
        generate) nds_git_auth_wizard_generate || return 1 ;;
        gh)
            gh_repo="${owner}/${repo}"
            nds_git_auth_wizard_gh "$gh_repo" || return 1
            ;;
        show)
            nds_git_key_show_pubkey || nds_git_auth_wizard_generate || return 1
            nds_git_key_show_qr || true
            nds_askUserToProceed "Registered the key — re-check access?" || return 1
            ;;
        retry) return 0 ;;
        skip) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Wizard step when multiple flake git inputs lack access.
# Arguments:
# - failed_urls: <String...> URLs that failed probe
# Returns:
# - <Int> 0 continue probe loop, 2 user chose skip
nds_git_auth_wizard_step_closure() {
    local -a failed=("$@")
    local -a gh_repos=()
    local choice url repo_line

    mapfile -t gh_repos < <(_nds_git_urls_to_github_repos "${failed[@]}")

    nds_ui_b ""
    nds_cfg_ask_choice GIT_AUTH_METHOD "Deploy key setup (all missing repos)" \
        "import|generate|gh|show|retry|skip" \
        "import=Import shared key|generate=Generate + QR|gh=Register on GitHub (all listed)|show=Show public key|retry=Re-check|skip=Skip (try anyway)" \
        "import"

    choice="$(nds_cfg_get GIT_AUTH_METHOD)"
    case "$choice" in
        import) nds_git_auth_wizard_import || return 1 ;;
        generate) nds_git_auth_wizard_generate || return 1 ;;
        gh)
            [[ ${#gh_repos[@]} -gt 0 ]] || {
                warn "No github.com repos in the failure list — register keys manually"
                nds_git_key_show_pubkey || return 1
                return 0
            }
            nds_git_auth_wizard_gh "${gh_repos[@]}" || return 1
            ;;
        show)
            nds_git_key_show_pubkey || nds_git_auth_wizard_generate || return 1
            nds_git_key_show_qr || true
            nds_askUserToProceed "Added deploy keys on every repo above — re-check?" || return 1
            ;;
        retry) return 0 ;;
        skip) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}
