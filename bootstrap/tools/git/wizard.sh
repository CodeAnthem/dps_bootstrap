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
        _out=(nix --extra-experimental-features "nix-command flakes" shell nixpkgs#gh -c gh)
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

# Description: Collect HTTPS deploy-keys page URLs for QR display.
nds_git_auth_collect_register_urls() {
    local url parsed host owner repo keys_url
    NDS_GIT_AUTH_REGISTER_URLS=()
    for url in "$@"; do
        url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        keys_url=$(_nds_git_keys_url "$host" "$owner" "$repo")
        [[ "$keys_url" == http* ]] && NDS_GIT_AUTH_REGISTER_URLS+=("$keys_url")
    done
}

# Description: True when the public key is already a deploy key on the repo.
_nds_git_gh_pubkey_on_repo() {
    local repo="$1" pub_file="$2"
    local key_line
    local -a gh_cmd=()

    _nds_git_gh_cmd gh_cmd || return 1
    key_line="$(awk '{print $1" "$2}' "$pub_file")"
    "${gh_cmd[@]}" api "repos/${repo}/keys" --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_line"
}

# Description: Add one deploy key via gh; surface errors and detect already-registered keys.
_nds_git_gh_deploy_key_add() {
    local pub_file="$1" repo="$2" title="$3"
    local -a gh_cmd=()
    local err rc

    _nds_git_gh_cmd gh_cmd || return 1

    if _nds_git_gh_pubkey_on_repo "$repo" "$pub_file"; then
        success "Deploy key already on ${repo} (${title})"
        nds_install_log "git: deploy key already on ${repo}"
        return 0
    fi

    # gh default is read-only; only -w/--allow-write grants write access
    err=$("${gh_cmd[@]}" repo deploy-key add "$pub_file" -R "$repo" \
        -t "$title" 2>&1) || rc=$?
    if [[ "${rc:-0}" -eq 0 ]]; then
        success "Deploy key registered on ${repo} (${title})"
        nds_install_log "git: gh deploy key -> ${repo}"
        return 0
    fi

    if _nds_git_gh_pubkey_on_repo "$repo" "$pub_file"; then
        success "Deploy key already on ${repo} (${title})"
        return 0
    fi

    warn "Could not add deploy key on ${repo}"
    nds_ui_i "  ${err}"
    nds_ui_i "  Check: admin access on the repo, org SSO authorized for gh, or remove an old deploy key with the same title."
    return 1
}

nds_git_gh_register_deploy_keys() {
    local pub_file="$1" key_title
    shift
    local -a repos=("$@") repo
    local -a gh_cmd=()
    local failed=0

    [[ -f "$pub_file" ]] || { error "Public key missing: $pub_file"; return 1; }
    [[ ${#repos[@]} -gt 0 ]] || { warn "No GitHub repos to register"; return 1; }
    _nds_git_gh_cmd gh_cmd || {
        error "gh CLI not available (install gh or use nix on the live ISO)"
        return 1
    }

    key_title="$(nds_git_deploy_key_title)"
    nds_git_key_load "$(nds_git_session_key_path)" || true

    if ! "${gh_cmd[@]}" auth status &>/dev/null; then
        info "GitHub device login (temporary — used only to add deploy keys)"
        nds_ui_b "Complete login in the browser, then return here."
        nds_ui_b "If the org uses SSO, authorize the token for CodeAnthem after login."
        "${gh_cmd[@]}" auth login --web --git-protocol ssh --scopes repo || return 1
    fi

    for repo in "${repos[@]}"; do
        [[ -n "$repo" ]] || continue
        _nds_git_gh_deploy_key_add "$pub_file" "$repo" "$key_title" || failed=1
    done

    "${gh_cmd[@]}" auth logout --hostname github.com 2>/dev/null || true
    nds_ui_i "GitHub session cleared."

    [[ "$failed" -eq 0 ]]
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

# Description: Resolve QR vs printed copy (env or yes/no prompt).
# Returns:
# - <String> "qr" or "copy" on stdout
nds_git_auth_resolve_key_display() {
    local from_env="${NDS_GIT_DEPLOY_KEY_DISPLAY:-}"
    case "${from_env,,}" in
        qr) printf 'qr\n'; return 0 ;;
        copy) printf 'copy\n'; return 0 ;;
    esac
    if nds_env_is_true "${NDS_GIT_DEPLOY_KEY_USE_QR:-false}"; then
        printf 'qr\n'
        return 0
    fi
    if [[ "${NDS_GIT_DEPLOY_KEY_USE_QR:-}" == "false" ]]; then
        printf 'copy\n'
        return 0
    fi
    nds_cfg_ask_toggle GIT_DEPLOY_KEY_USE_QR "Use QR codes" false
    if nds_cfg_true GIT_DEPLOY_KEY_USE_QR; then
        printf 'qr\n'
    else
        printf 'copy\n'
    fi
}

# Description: After user chose QR, install qrencode before generate/show.
nds_git_auth_prepare_qr_display() {
    local display="$1"
    [[ "$display" == "qr" ]] || return 0
    nds_git_qr_preinstall || {
        warn "QR unavailable — falling back to printed copy"
        return 1
    }
    return 0
}

# Description: Show existing deploy key and confirm GitHub registration.
nds_git_auth_wizard_show_key() {
    local display="$1"
    nds_git_auth_prepare_qr_display "$display" || display="copy"
    nds_git_key_show_deploy_pubkey "$display" || return 1
    nds_git_auth_confirm_manual_register "$display" || return 1
    return 0
}

nds_git_auth_wizard_generate() {
    local display
    display="$(nds_git_auth_resolve_key_display)" || return 1
    nds_git_auth_prepare_qr_display "$display" || display="copy"
    nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    nds_git_key_show_deploy_pubkey "$display" || return 1
    nds_git_auth_confirm_manual_register "$display" || return 1
    return 0
}

# Description: Wait until user confirms deploy key was added on GitHub (manual paste path).
# Arguments:
# - display: <String> "qr" or "copy"
# Returns:
# - 0 when user confirms, 1 when they decline
nds_git_auth_confirm_manual_register() {
    local display="${1:-copy}"

    nds_ui_b "Register the public key on each repo above — read-only is enough."
    nds_ui_b ""
    if [[ "$display" == "qr" ]]; then
        nds_ui_i "QR 1: deploy-keys page URL — open in phone browser."
        nds_ui_i "QR 2: public key — paste on that page (title: $(nds_git_deploy_key_title))."
    else
        nds_ui_i "Copy the public key and open each deploy-keys link in a browser."
    fi
    nds_ui_i "Repeat for every repo in the list — same key on each."
    nds_ui_b ""
    nds_askUserToProceed "Added this deploy key on every repo listed above?" || return 1
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
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
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
    local choice gh_label gh_scope display=""

    if [[ ${#gh_repos[@]} -gt 1 ]]; then
        gh_scope="all ${#gh_repos[@]} listed GitHub repos automatically"
    elif [[ ${#gh_repos[@]} -eq 1 ]]; then
        gh_scope="${gh_repos[0]} automatically"
    else
        gh_scope="listed GitHub repos (none here — use generate/show)"
    fi
    gh_label="GitHub CLI (gh) — browser login once, adds read-only key to ${gh_scope}"

    nds_ui_h "What do you want to do?"
    nds_cfg_ask_choice GIT_AUTH_METHOD "Deploy key — ${scope_label}" \
        "import|generate|gh|show|retry|skip" \
        "import=Import key from USB or path (existing deploy key)|generate=Generate new ed25519 key ($(nds_git_deploy_key_title))|gh=${gh_label}|show=Show public key again|retry=Re-check SSH access (no key change)|skip=Skip — continue anyway (clone may fail)" \
        "import"

    choice="$(nds_cfg_get GIT_AUTH_METHOD)"
    case "$choice" in
        import) nds_git_auth_wizard_import || return 1 ;;
        generate) nds_git_auth_wizard_generate || return 1 ;;
        gh)
            [[ ${#gh_repos[@]} -gt 0 ]] || {
                warn "No github.com repos — use Show public key and paste manually"
                if [[ -f "$(nds_git_session_pubkey_path)" ]]; then
                    display="$(nds_git_auth_resolve_key_display)" || return 1
                    nds_git_auth_wizard_show_key "$display" || return 1
                else
                    nds_git_auth_wizard_generate || return 1
                fi
                return 0
            }
            nds_git_auth_wizard_gh "${gh_repos[@]}" || return 1
            ;;
        show)
            if [[ -f "$(nds_git_session_pubkey_path)" ]]; then
                display="$(nds_git_auth_resolve_key_display)" || return 1
                nds_git_auth_wizard_show_key "$display" || return 1
            else
                nds_git_auth_wizard_generate || return 1
            fi
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

    _nds_git_auth_screen_intro
    nds_git_auth_collect_register_urls "$(_nds_git_to_ssh "$host" "$owner" "$repo")"
    nds_ui_h "Repository"
    _nds_git_auth_print_repo "$(_nds_git_to_ssh "$host" "$owner" "$repo")" "missing"
    nds_ui_b ""

    nds_git_auth_prompt_method "this repository" "${owner}/${repo}"
}

# Description: Full screen when flake.lock inputs lack access.
nds_git_auth_screen_closure() {
    local -a failed=("$@")
    local -a gh_repos=()
    local -a all_urls=()
    local url

    mapfile -t gh_repos < <(_nds_git_urls_to_github_repos "${failed[@]}")

    _nds_git_auth_screen_intro
    nds_git_auth_collect_register_urls "${failed[@]}"

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
        nds_ui_i "gh: browser login once — adds the deploy key to all ${#gh_repos[@]} GitHub repo(s) above."
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
