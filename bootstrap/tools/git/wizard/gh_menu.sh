#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard GitHub CLI menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Run gh auth login via device code (no local browser).
# Returns:
# - <Bool> 0 on success
_nds_git_wizard_gh_auth_login() {
    local -a gh_cmd=()
    local rc=0

    nds_git_gh_cmd gh_cmd || return 1
    nds_git_gh_unset_blocking_tokens

    BROWSER=false "${gh_cmd[@]}" auth login \
        --hostname github.com \
        --git-protocol ssh \
        --scopes repo,admin:public_key \
        --skip-ssh-key || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        warn "GitHub login failed"
        nds_ui_i "Open https://github.com/login/device on your phone and enter the one-time code."
        nds_ui_i "If this keeps failing, unset GITHUB_TOKEN / GH_TOKEN in your shell and retry."
        nds_ui_i "You can also choose manual registration from the menu."
        return 1
    fi
    return 0
}

# Description: Interactive gh device login and scope refresh.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_gh_ensure_auth() {
    local -a gh_cmd=()

    section_header "GitHub CLI login"
    nds_git_gh_cmd gh_cmd || return 1

    if ! nds_git_gh_session_active; then
        nds_ui_b "gh prints a one-time code — use it on another device (phone or laptop)."
        nds_ui_b "Open https://github.com/login/device or follow the URL gh prints."
        nds_ui_b "If the GitHub Android/iOS app is logged in, approve the prompt there"
        nds_ui_b "or finish in mobile Chrome — no browser needed on this VM."
        nds_ui_b "If the org uses SSO, authorize gh for your org after login."
        nds_ui_b "The gh session is cleared after a successful install (SSH key stays on GitHub)."
        nds_ui_b ""
        _nds_git_wizard_gh_auth_login || return 1
        success "GitHub login successful"
        return 0
    fi

    if ! nds_git_gh_has_key_scope; then
        nds_ui_h "Extend GitHub session"
        nds_ui_b "Adding admin:public_key scope to register SSH keys."
        nds_ui_b "Confirm on your phone or browser if prompted."
        nds_ui_b ""
        nds_git_gh_unset_blocking_tokens
        BROWSER=false "${gh_cmd[@]}" auth refresh -h github.com -s repo,admin:public_key || return 1
    fi
    return 0
}

# Description: gh auto-register path — prefetch gh, login, add read-only account key.
# Arguments:
# - repos: <String...> owner/repo seeds
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_gh() {
    local -a repos=("$@")
    local pub

    [[ ${#repos[@]} -gt 0 ]] || return 1

    if ! command -v gh &>/dev/null; then
        nds_git_gh_prefetch || {
            error "Could not install gh CLI"
            return 1
        }
    fi

    nds_git_wizard_gh_ensure_auth || return 1

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi
    pub="$(nds_git_session_pubkey_path)"

    if nds_git_gh_register_for_repos "$pub" "${repos[@]}"; then
        success "Read-only SSH key registered on your GitHub account ($(nds_git_ssh_key_title))"
        nds_ui_i "Private key will be copied to $(nds_git_target_key_abs) on the target."
        return 0
    fi
    return 1
}
