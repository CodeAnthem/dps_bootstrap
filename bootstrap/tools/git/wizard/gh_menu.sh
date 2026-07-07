#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard GitHub CLI menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Run gh auth login via device code (no local browser).
_nds_git_wizard_gh_auth_login() {
    local -a gh_cmd=()
    local rc=0

    nds_git_gh_cmd gh_cmd || return 1
    nds_git_gh_unset_blocking_tokens

    nds_ui_b "gh stores a short-lived session on this ISO (plain text — no credential store on the live image)."
    nds_ui_b "Complete login on your phone when gh prints the device code."
    nds_ui_b ""

    if declare -f step_start &>/dev/null; then
        step_start "GitHub device login"
    fi

    BROWSER=false "${gh_cmd[@]}" auth login \
        --hostname github.com \
        --git-protocol ssh \
        --scopes repo,admin:public_key \
        --skip-ssh-key \
        --insecure-storage || rc=$?

    if declare -f step_complete &>/dev/null; then
        if [[ "$rc" -eq 0 ]]; then
            step_complete "GitHub device login"
        else
            step_fail "GitHub device login"
        fi
    fi

    if [[ "$rc" -ne 0 ]]; then
        warn "GitHub login failed"
        nds_ui_i "Open https://github.com/login/device on your phone and enter the one-time code."
        nds_ui_i "If this keeps failing, unset GITHUB_TOKEN / GH_TOKEN in your shell and retry."
        nds_ui_i "You can also choose manual registration from the menu."
        return 1
    fi
    nds_git_gh_session_mark_scopes_ok
    return 0
}

# Description: Interactive gh device login and scope refresh.
nds_git_wizard_gh_ensure_auth() {
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1

    if nds_git_gh_session_ready; then
        return 0
    fi

    if ! nds_git_gh_session_active; then
        nds_ui_b "gh prints a one-time code — use it on another device (phone or laptop)."
        nds_ui_b "Open https://github.com/login/device or follow the URL gh prints."
        nds_ui_b "If the org uses SSO, authorize gh for your org after login."
        nds_ui_b "The gh session is cleared after a successful install (keys stay on GitHub)."
        nds_ui_b ""
        _nds_git_wizard_gh_auth_login || return 1
        success "GitHub login successful"
        return 0
    fi

    if ! nds_git_gh_has_key_scope; then
        nds_ui_h "Extend GitHub session"
        nds_ui_b "Adding repo and admin:public_key scopes."
        nds_ui_b "Confirm on your phone or browser if prompted."
        nds_ui_b ""
        nds_git_gh_unset_blocking_tokens
        BROWSER=false "${gh_cmd[@]}" auth refresh -h github.com -s repo,admin:public_key || return 1
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
    if ! nds_git_gh_session_active 2>/dev/null; then
        section_header "GitHub CLI login"
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
    info "Registering read-only deploy key on GitHub (${owner}/${repo})..."
    if nds_git_gh_register_deploy_for_repo "$owner" "$repo"; then
        success "Read-only deploy key registered on ${owner}/${repo}"
        nds_ui_i "Private key: $(nds_git_deploy_key_path "$owner" "$repo")"
        nds_ui_i "Target: /$(nds_git_deploy_key_target_rel "$owner" "$repo")"
        return 0
    fi
    error "Could not register deploy key on ${owner}/${repo}"
    nds_ui_i "  gh needs admin access to the repository and org SSO authorization."
    return 1
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
