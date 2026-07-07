#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard GitHub CLI menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Print device-login lines from captured gh output.
_nds_git_wizard_gh_show_device_prompt() {
    local log="$1" line

    section_header "GitHub device login"
    nds_ui_b "gh stores a short-lived session on this ISO (plain text — no credential store on the live image)."
    nds_ui_b "Complete login on your phone using the code below."
    nds_ui_b ""
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
            *one-time\ code*|*login/device*|*First\ copy*)
                nds_ui_i "$line"
                ;;
        esac
    done < "$log"
    nds_ui_b ""
}

# Description: Run gh auth login via device code (spinner until code, then wait for auth).
_nds_git_wizard_gh_auth_login() {
    local -a gh_cmd=()
    local rc=0 log pid shown=false delay=0.12 spinstr="|/-\\"
    local char logfile="${NDS_RUNTIME_DIR:-/tmp/nds}/gh_auth.log"

    nds_git_gh_cmd gh_cmd || return 1
    nds_git_gh_unset_blocking_tokens

    mkdir -p "$(dirname "$logfile")"
    : >"$logfile"

    (
        BROWSER=false "${gh_cmd[@]}" auth login \
            --hostname github.com \
            --git-protocol ssh \
            --scopes repo,admin:public_key \
            --skip-ssh-key \
            --insecure-storage
    ) >>"$logfile" 2>&1 &
    pid=$!

    step_start "GitHub device login"
    while kill -0 "$pid" 2>/dev/null; do
        if ! $shown && grep -qiE 'one-time code|login/device' "$logfile" 2>/dev/null; then
            printf '\r\033[K' >&2
            _nds_git_wizard_gh_show_device_prompt "$logfile"
            step_start "Waiting for GitHub authorization"
            shown=true
        fi
        char="${spinstr:0:1}"
        if $shown; then
            printf '\r\033[K%s[%s%s] Waiting for GitHub authorization' \
                "$NDS_UI_INDENT_B" "$char" "$char" >&2
        else
            printf '\r\033[K%s[%s%s] GitHub device login' \
                "$NDS_UI_INDENT_B" "$char" "$char" >&2
        fi
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep "$delay"
    done
    wait "$pid" || rc=$?

    if [[ "$rc" -eq 0 ]]; then
        printf '\r\033[K' >&2
        if $shown; then
            step_complete "Waiting for GitHub authorization"
        else
            step_complete "GitHub device login"
        fi
        return 0
    fi
    printf '\r\033[K' >&2
    step_fail "GitHub device login"
    warn "GitHub login failed"
    nds_ui_i "Open https://github.com/login/device on your phone and enter the one-time code."
    nds_ui_i "If this keeps failing, unset GITHUB_TOKEN / GH_TOKEN in your shell and retry."
    nds_ui_i "You can also choose manual registration from the menu."
    return 1
}

# Description: Interactive gh device login and scope refresh.
nds_git_wizard_gh_ensure_auth() {
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1

    if nds_git_gh_session_ready; then
        return 0
    fi

    if ! nds_git_gh_session_active; then
        _nds_git_wizard_gh_auth_login || return 1
        nds_git_gh_session_mark_scopes_ok
        success "GitHub login successful"
        return 0
    fi

    if ! nds_git_gh_has_key_scope; then
        step_start "Extending GitHub session"
        nds_git_gh_unset_blocking_tokens
        BROWSER=false "${gh_cmd[@]}" auth refresh -h github.com -s repo,admin:public_key || {
            step_fail "Extending GitHub session"
            return 1
        }
        step_complete "Extending GitHub session"
        nds_git_gh_session_mark_scopes_ok
    fi
    return 0
}

# Description: Ensure gh is available and authenticated.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_gh_prepare() {
    nds_git_gh_ensure_prefetch || {
        error "Could not install gh CLI"
        return 1
    }
    if nds_git_gh_session_ready; then
        return 0
    fi
    nds_git_wizard_gh_ensure_auth || return 1
    return 0
}

# Description: gh path — register read-only deploy key on one repository.
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_gh_deploy() {
    local owner="$1" repo="$2"

    nds_git_wizard_gh_prepare || return 1
    if declare -f nds_step_exec &>/dev/null; then
        nds_step_exec "Registering deploy key on ${owner}/${repo}" \
            nds_git_gh_register_deploy_for_repo "$owner" "$repo" || return 1
    else
        info "Registering read-only deploy key on GitHub (${owner}/${repo})..."
        nds_git_gh_register_deploy_for_repo "$owner" "$repo" || return 1
    fi
    success "Read-only deploy key registered on ${owner}/${repo}"
    nds_ui_i "Private key: $(nds_git_deploy_key_path "$owner" "$repo")"
    nds_ui_i "Target: /$(nds_git_deploy_key_target_rel "$owner" "$repo")"
    nds_git_ssh_config_refresh || true
    return 0
}

# Description: gh path — register account SSH key (log in as machine user).
# Arguments:
# - repos: <String...> owner/repo for logging
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_gh_account() {
    local -a repos=("$@")
    local pub

    nds_ui_b "Log in to gh as your machine GitHub user — not your personal account."
    nds_ui_b ""

    nds_git_wizard_gh_prepare || return 1

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi
    pub="$(nds_git_session_pubkey_path)"
    nds_git_keys_register "$(nds_git_session_key_path)" || true
    nds_git_auth_set_mode account

    info "Registering SSH key on the logged-in GitHub account..."
    if nds_git_gh_register_for_repos "$pub" "${repos[@]}"; then
        success "SSH key registered on GitHub account ($(nds_git_ssh_key_title))"
        nds_ui_i "Private key will be copied to $(nds_git_target_key_abs) on the target."
        return 0
    fi
    return 1
}

# Compatibility alias (deprecated — use deploy or account menus).
nds_git_wizard_menu_gh() {
    local -a repos=("$@")
    nds_git_wizard_menu_gh_account "${repos[@]}"
}
