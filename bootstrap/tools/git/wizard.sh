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

# Description: Fetch flake.lock from GitHub via gh API (requires active gh auth).
# Arguments:
# - gh_repo: <String> owner/repo
# Returns:
# - <String> git remote URLs from the lock (stdout), empty when unavailable
_nds_git_gh_lock_git_urls() {
    local gh_repo="$1"
    local owner repo content tmp
    local -a gh_cmd=()

    owner="${gh_repo%%/*}"
    repo="${gh_repo##*/}"
    [[ -n "$owner" && -n "$repo" ]] || return 0

    _nds_git_gh_cmd gh_cmd || return 0
    content=$("${gh_cmd[@]}" api "repos/${owner}/${repo}/contents/flake.lock" \
        --jq -r '.content // empty' 2>/dev/null) || return 0
    [[ -n "$content" ]] || return 0

    tmp="$(mktemp)"
    if ! printf '%s' "$content" | tr -d '\n' | base64 -d > "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 0
    fi
    _nds_flake_lock_ssh_urls "$tmp"
    rm -f "$tmp"
}

# Description: Merge root repo(s) with GitHub repos referenced in their flake.lock.
# Arguments:
# - repos: <String...> owner/repo seeds (typically the root flake)
# Returns:
# - <String> Deduped owner/repo lines (stdout)
_nds_git_gh_expand_github_repos() {
    local -a seeds=("$@")
    local -a out=()
    local gh_repo url

    out=("${seeds[@]}")
    for gh_repo in "${seeds[@]}"; do
        [[ -n "$gh_repo" ]] || continue
        mapfile -t out < <(printf '%s\n' "${out[@]}" \
            $(_nds_git_urls_to_github_repos "git@github.com:${gh_repo}.git"))
        while IFS= read -r url; do
            [[ -n "$url" ]] || continue
            mapfile -t out < <(printf '%s\n' "${out[@]}" \
                $(_nds_git_urls_to_github_repos "$url"))
        done < <(_nds_git_gh_lock_git_urls "$gh_repo")
    done
    printf '%s\n' "${out[@]}" | awk 'NF' | sort -u
}

# Description: Ensure gh is logged in with repo + admin:public_key (required for ssh-key add).
_nds_git_gh_ensure_auth() {
    local -a gh_cmd=()

    _nds_git_gh_cmd gh_cmd || return 1

    if ! "${gh_cmd[@]}" auth status &>/dev/null; then
        info "GitHub device login (temporary — used only to register SSH access)"
        nds_ui_b "Complete login in the browser, then return here."
        nds_ui_b "If the org uses SSO, authorize the token for CodeAnthem after login."
        nds_ui_b "gh may warn that credentials are stored in plain text — expected on the live ISO."
        "${gh_cmd[@]}" auth login --web --git-protocol ssh --scopes repo,admin:public_key || return 1
        return 0
    fi

    if ! "${gh_cmd[@]}" auth status --show-token-scopes 2>/dev/null | grep -qF 'admin:public_key'; then
        info "Extending GitHub token scope (admin:public_key) to register SSH keys"
        nds_ui_b "Confirm in the browser if prompted."
        "${gh_cmd[@]}" auth refresh -h github.com -s repo,admin:public_key || return 1
    fi
    return 0
}

# Description: End temporary gh auth on the live ISO (SSH keys on GitHub are kept for the target).
nds_git_gh_session_cleanup() {
    local -a gh_cmd=()

    _nds_git_gh_cmd gh_cmd || return 0
    if "${gh_cmd[@]}" auth status &>/dev/null; then
        "${gh_cmd[@]}" auth logout --hostname github.com 2>/dev/null || true
        nds_install_log "git: gh token cleared from live ISO (SSH key left on GitHub)"
    fi
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

# Description: True when the public key is on the logged-in GitHub user account.
_nds_git_gh_pubkey_on_user() {
    local pub_file="$1"
    local key_line
    local -a gh_cmd=()

    _nds_git_gh_cmd gh_cmd || return 1
    key_line="$(awk '{print $1" "$2}' "$pub_file")"
    "${gh_cmd[@]}" ssh-key list --json key --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_line"
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

# Description: Delete deploy keys on a repo that use the NDS title (stale installs).
# Arguments:
# - repo:  <String> owner/repo
# - title: <String> Deploy key title to remove
_nds_git_gh_remove_deploy_keys_by_title() {
    local repo="$1" title="$2"
    local id
    local -a gh_cmd=()

    _nds_git_gh_cmd gh_cmd || return 1
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if "${gh_cmd[@]}" repo deploy-key delete "$id" -R "$repo" 2>/dev/null; then
            info "Removed stale deploy key on ${repo} (${title})"
            nds_install_log "git: removed deploy key ${title} on ${repo}"
        fi
    done < <("${gh_cmd[@]}" repo deploy-key list -R "$repo" --json id,title \
        --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null)
}

# Description: Delete account SSH keys that use the NDS title (stale installs).
# Arguments:
# - title: <String> SSH key title to remove
_nds_git_gh_remove_user_ssh_keys_by_title() {
    local title="$1"
    local id
    local -a gh_cmd=()

    _nds_git_gh_cmd gh_cmd || return 1
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if "${gh_cmd[@]}" ssh-key delete "$id" 2>/dev/null; then
            info "Removed stale account SSH key (${title})"
            nds_install_log "git: removed account SSH key ${title}"
        fi
    done < <("${gh_cmd[@]}" ssh-key list --json id,title \
        --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null)
}

# Description: Register session pubkey on the GitHub account (one key, all private repos).
# GitHub deploy keys cannot reuse the same pubkey across repos; account SSH keys can.
# Arguments:
# - pub_file: <String> Public key path
# - title:    <String> Key title (nds-<host>)
# Returns:
# - <Bool> 0 on success
_nds_git_gh_user_ssh_key_ensure() {
    local pub_file="$1" title="$2"
    local -a gh_cmd=()
    local err rc

    _nds_git_gh_cmd gh_cmd || return 1

    if _nds_git_gh_pubkey_on_user "$pub_file"; then
        success "SSH key already on GitHub account (${title})"
        nds_install_log "git: account SSH key already present"
        nds_ui_i "Private key will be copied to $(nds_git_target_key_abs) on the target."
        return 0
    fi

    _nds_git_gh_remove_user_ssh_keys_by_title "$title"

    err=$("${gh_cmd[@]}" ssh-key add "$pub_file" -t "$title" 2>&1) || rc=$?
    if [[ "${rc:-0}" -eq 0 ]]; then
        success "SSH key added to GitHub account (${title})"
        nds_install_log "git: account SSH key added (kept for installed host)"
        nds_ui_i "Private key will be copied to $(nds_git_target_key_abs) on the target."
        return 0
    fi

    if _nds_git_gh_pubkey_on_user "$pub_file"; then
        success "SSH key already on GitHub account (${title})"
        nds_ui_i "Private key will be copied to $(nds_git_target_key_abs) on the target."
        return 0
    fi

    warn "Could not add SSH key to GitHub account"
    nds_ui_i "  ${err}"
    nds_ui_i "  Check: org SSO authorized for gh, token has admin:public_key scope, or remove an old key with the same title on github.com/settings/keys."
    return 1
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

    _nds_git_gh_remove_deploy_keys_by_title "$repo" "$title"

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

    _nds_git_gh_ensure_auth || return 1

    mapfile -t repos < <(_nds_git_gh_expand_github_repos "${repos[@]}")
    info "GitHub: adding one account SSH key for ${#repos[@]} private repo(s) (deploy keys cannot share a pubkey)"
    for repo in "${repos[@]}"; do
        [[ -n "$repo" ]] || continue
        _nds_git_gh_remove_deploy_keys_by_title "$repo" "$key_title"
    done

    _nds_git_gh_user_ssh_key_ensure "$pub_file" "$key_title" || failed=1

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
    nds_ui_b "Private flakes need SSH git access. NDS checks every git input"
    nds_ui_b "(your flake URL plus locked inputs in flake.lock)."
    nds_ui_b ""
    nds_ui_b "One SSH key for this session — use gh (GitHub account key, all repos),"
    nds_ui_b "or import / generate and register on GitHub manually."
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
    local url ssh_url parsed host owner repo key
    declare -A repo_status=() repo_sample=()

    nds_ui_h "Repositories"
    for url in "${_urls[@]}"; do
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        key="${owner}/${repo}"
        repo_sample[$key]="$url"
        [[ -z "${repo_status[$key]:-}" ]] && repo_status[$key]="ok"
    done
    for url in "${_failed[@]}"; do
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        repo_status["${owner}/${repo}"]="missing"
        [[ -z "${repo_sample[${owner}/${repo}]:-}" ]] && repo_sample["${owner}/${repo}"]="$url"
    done
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        _nds_git_auth_print_repo "${repo_sample[$key]}" "${repo_status[$key]}"
    done < <(printf '%s\n' "${!repo_status[@]}" | sort)
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
        gh_scope="your GitHub account (one SSH key for all ${#gh_repos[@]} listed repos)"
    elif [[ ${#gh_repos[@]} -eq 1 ]]; then
        gh_scope="your GitHub account (${gh_repos[0]} + flake.lock inputs)"
    else
        gh_scope="your GitHub account (use generate/show if no github.com repos)"
    fi
    gh_label="GitHub CLI (gh) — browser login once, adds read-only SSH key to ${gh_scope}"

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
        declare -A _missing_printed=()
        local ssh_url parsed host owner repo mkey
        for url in "${failed[@]}"; do
            ssh_url=$(_nds_git_ssh_url "$url")
            parsed=$(_nds_git_parse "$ssh_url") || continue
            IFS=$'\t' read -r host owner repo <<< "$parsed"
            mkey="${owner}/${repo}"
            [[ -n "${_missing_printed[$mkey]:-}" ]] && continue
            _missing_printed[$mkey]=1
            _nds_git_auth_print_repo "$url" "missing"
        done
        nds_ui_b ""
    fi

    if [[ ${#gh_repos[@]} -gt 0 ]]; then
        nds_ui_i "gh: browser login once — adds one SSH key to your account for all ${#gh_repos[@]} listed repo(s)."
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
