#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth wizard
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-06
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

nds_git_auth_wizard_generate() {
    nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    nds_git_key_show_pubkey || return 1
    nds_git_key_show_qr || true
    nds_ui_b "Add this public key as read-only on every repo listed above."
    return 0
}

nds_git_auth_wizard_gh() {
    local -a repos=("$@")
    local pub

    [[ ${#repos[@]} -gt 0 ]] || {
        warn "No GitHub repositories in scope — add keys manually (Show public key)"
        return 1
    }

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_auth_wizard_generate || return 1
    fi
    pub="$(nds_git_session_pubkey_path)"
    nds_git_gh_register_deploy_keys "$pub" "${repos[@]}"
}

# Description: Short intro — one key, all repos.
_nds_git_auth_screen_intro() {
    section_header "Private repository access"
    nds_ui_b "Private flakes need SSH deploy keys. NDS checks every git input"
    nds_ui_b "(your flake URL plus locked inputs in flake.lock)."
    nds_ui_b ""
    nds_ui_b "One deploy key is used for this session — the same public key must be"
    nds_ui_b "registered on each private repo below (read-only is enough)."
    nds_ui_b ""
}

# Description: Print one repo line with optional missing marker.
_nds_git_auth_print_repo() {
    local url="$1"
    local status="${2:-}"
    local ssh_url parsed host owner repo

    ssh_url=$(_nds_git_ssh_url "$url")
    if parsed=$(_nds_git_parse "$ssh_url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$status" == "ok" ]]; then
            nds_ui_i "  [ok]  ${owner}/${repo}"
        elif [[ "$status" == "missing" ]]; then
            nds_ui_i "  [!!]  ${owner}/${repo}"
        else
            nds_ui_i "  ${owner}/${repo}"
        fi
        nds_ui_i "        $(_nds_git_keys_url "$host" "$owner" "$repo")"
    else
        nds_ui_i "  ${ssh_url}"
    fi
}

# Description: List repositories with access status (closure check).
# Arguments:
# - urls_var:   <Nameref> All URLs checked
# - failed_var: <Nameref> URLs that failed probe
_nds_git_auth_screen_list_repos() {
    local -n _urls=$1
    local -n _failed=$2
    local url f missing=0

    nds_ui_h "Repositories"
    for url in "${_urls[@]}"; do
        missing=0
        for f in "${_failed[@]}"; do
            [[ "$f" == "$url" ]] && { missing=1; break; }
        done
        if [[ "$missing" -eq 1 ]]; then
            _nds_git_auth_print_repo "$url" "missing"
        else
            _nds_git_auth_print_repo "$url" "ok"
        fi
    done
    nds_ui_b ""
}

# Description: Prompt deploy-key method (shared by single-repo and closure flows).
# Arguments:
# - scope_label: <String> e.g. "one repo" or "all missing repos"
# - gh_repos:    <String...> owner/repo for gh auto-register (may be empty)
nds_git_auth_prompt_method() {
    local scope_label="$1"
    shift
    local -a gh_repos=("$@")
    local choice gh_hint

    gh_hint="Register on GitHub (browser login)"
    if [[ ${#gh_repos[@]} -gt 1 ]]; then
        gh_hint="${gh_hint}, all ${#gh_repos[@]} repos at once"
    elif [[ ${#gh_repos[@]} -eq 1 ]]; then
        gh_hint="${gh_hint}, ${gh_repos[0]}"
    else
        gh_hint="${gh_hint} — no github.com repos in list; use Show instead"
    fi

    nds_ui_h "What do you want to do?"
    nds_cfg_ask_choice GIT_AUTH_METHOD "Deploy key — ${scope_label}" \
        "import|generate|gh|show|retry|skip" \
        "import=Import key from USB or path (use an existing deploy key)|generate=Generate new key + show QR (register on each repo next)|gh=${gh_hint}|show=Show public key + QR again (manual paste on GitHub)|retry=Re-check SSH access (no key change)|skip=Skip — continue anyway (clone may fail)" \
        "import"

    choice="$(nds_cfg_get GIT_AUTH_METHOD)"
    case "$choice" in
        import) nds_git_auth_wizard_import || return 1 ;;
        generate) nds_git_auth_wizard_generate || return 1 ;;
        gh)
            [[ ${#gh_repos[@]} -gt 0 ]] || {
                warn "No github.com repos — use Show public key and paste manually"
                nds_git_key_show_pubkey || nds_git_auth_wizard_generate || return 1
                nds_git_key_show_qr || true
                return 0
            }
            nds_git_auth_wizard_gh "${gh_repos[@]}" || return 1
            ;;
        show)
            nds_git_key_show_pubkey || nds_git_auth_wizard_generate || return 1
            nds_git_key_show_qr || true
            nds_askUserToProceed "Registered the key on every repo above — re-check access?" || return 1
            ;;
        retry) return 0 ;;
        skip) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Full screen for a single root flake repo.
nds_git_auth_screen_single() {
    local host="$1" owner="$2" repo="$3"
    local -a gh_repos=("${owner}/${repo}")

    _nds_git_auth_screen_intro
    nds_ui_h "Repository"
    _nds_git_auth_print_repo "$(_nds_git_to_ssh "$host" "$owner" "$repo")" "missing"
    nds_ui_b ""

    nds_git_auth_prompt_method "this repository" "${gh_repos[@]}"
}

# Description: Full screen when flake.lock inputs lack access.
nds_git_auth_screen_closure() {
    local -a failed=("$@")
    local -a gh_repos=()
    local -a all_urls=()
    local url

    mapfile -t gh_repos < <(_nds_git_urls_to_github_repos "${failed[@]}")

    _nds_git_auth_screen_intro

    if [[ -n "${NDS_GIT_CLOSURE_URLS:-}" ]]; then
        readarray -t all_urls <<< "$NDS_GIT_CLOSURE_URLS"
    else
        all_urls=("${failed[@]}")
    fi

    if [[ ${#all_urls[@]} -gt 0 && ${#failed[@]} -lt ${#all_urls[@]} ]]; then
        _nds_git_auth_screen_list_repos all_urls failed
    else
        nds_ui_h "Repositories missing access"
        for url in "${failed[@]}"; do
            _nds_git_auth_print_repo "$url" "missing"
        done
        nds_ui_b ""
    fi

    if [[ ${#gh_repos[@]} -gt 0 ]]; then
        nds_ui_i "GitHub auto-register can add the deploy key to all ${#gh_repos[@]} repo(s) in one step."
        nds_ui_b ""
    fi

    nds_git_auth_prompt_method "all missing repos" "${gh_repos[@]}"
}

nds_git_auth_wizard_step_repo() {
    nds_git_auth_screen_single "$@"
}

nds_git_auth_wizard_step_closure() {
    nds_git_auth_screen_closure "$@"
}
