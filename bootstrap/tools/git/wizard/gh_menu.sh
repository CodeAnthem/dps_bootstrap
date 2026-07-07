#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard GitHub CLI menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Interactive gh device login and scope refresh.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_gh_ensure_auth() {
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1

    if ! nds_git_gh_session_active; then
        info "GitHub login (temporary — used only to register SSH access)"
        nds_ui_b "gh prints a one-time code and a github.com URL."
        nds_ui_b "On your phone: open the URL (or github.com/login/device and enter the code)."
        nds_ui_b "If the GitHub Android/iOS app is logged in, approve the prompt there"
        nds_ui_b "or finish in mobile Chrome — no browser needed on this VM."
        nds_ui_b "If the org uses SSO, authorize gh for your org after login."
        nds_ui_b "The gh session is cleared after a successful install (SSH key stays on GitHub)."
        "${gh_cmd[@]}" auth login --web --git-protocol ssh --scopes repo,admin:public_key || return 1
        return 0
    fi

    if ! nds_git_gh_has_key_scope; then
        info "Extending GitHub session scope (admin:public_key) to register SSH keys"
        nds_ui_b "Confirm in the browser if prompted."
        "${gh_cmd[@]}" auth refresh -h github.com -s repo,admin:public_key || return 1
    fi
    return 0
}

# Description: gh auto-register path — login, add read-only account key.
# Arguments:
# - repos: <String...> owner/repo seeds
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_gh() {
    local -a repos=("$@")
    local pub

    [[ ${#repos[@]} -gt 0 ]] || return 1
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
