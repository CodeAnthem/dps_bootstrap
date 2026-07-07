#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard new-key route menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: New SSH key route — gh auto when all hosts are GitHub, else manual.
# Arguments:
# - urls:  <String...> Git URLs in scope (host check)
# - repos: <String...> owner/repo for gh registration
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_new_key() {
    local -a urls=() repos=()
    local choice host parsing_repos=false arg

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

    if nds_git_urls_all_github "${urls[@]}" && nds_git_gh_available; then
        nds_ui_h "Register a new SSH key"
        nds_ui_b "NDS can add a read-only SSH key to your GitHub account via gh"
        nds_ui_b "(one-time device login). The gh session is cleared after install."
        nds_ui_b ""
        nds_cfg_ask_choice GIT_SSH_KEY_GH_AUTO \
            "Allow NDS to add the key via gh?" \
            "yes|no" \
            "yes=Yes — gh device login, read-only account key|no=No — show key and register manually" \
            "yes"
        choice="$(nds_cfg_get GIT_SSH_KEY_GH_AUTO)"
        if [[ "$choice" == "yes" ]]; then
            nds_git_wizard_menu_gh "${repos[@]}" || return 1
            return 0
        fi
    else
        host="$(nds_git_primary_host_from_urls "${urls[@]}")"
        if [[ -n "$host" ]] && ! nds_git_host_is_github "$host"; then
            info "Non-GitHub host (${host}) — register the SSH key manually on your account."
        elif ! nds_git_gh_available; then
            info "gh CLI not available — register the SSH key manually."
        fi
    fi

    nds_git_wizard_menu_manual || return 1
    return 0
}
