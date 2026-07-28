#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard flow (menu state machine)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Top-level route menu for git auth wizard.
# Arguments:
# - scope_label: <String> e.g. this repository
# - urls:        <String...> URLs to probe (import / host check)
# - repos:       <String...> owner/repo for gh (optional, after urls)
# Returns:
# - 0 action done, 1 retry menu, 2 skip
nds_git_wizard_route_menu() {
    local scope_label="$1"
    shift
    local -a urls=() repos=()
    local choice parsing_repos=false arg

    while [[ $# -gt 0 ]]; do
        arg="$1"
        shift
        if [[ "$arg" == "--repos" ]]; then
            parsing_repos=true
            repos=("$@")
            break
        fi
        urls+=("$arg")
    done

    nds_cfg_section_title "What do you want to do? (${scope_label})"
    nds_cfg_ask_numbered_choice GIT_AUTH_ROUTE \
        "import|new|retry|skip" \
        "import=I already have a key — scan cwd and ~/.ssh, or pick a path|new=Create or register a new SSH key|retry=Re-check SSH access (no key change)|skip=Skip — continue anyway (clone may fail)" \
        "import"

    choice="$(nds_cfg_get GIT_AUTH_ROUTE)"
    case "$choice" in
        import)
            nds_git_wizard_menu_import "${urls[@]}" || return 1
            ;;
        new)
            if [[ ${#repos[@]} -gt 0 ]]; then
                nds_git_wizard_menu_new_key "${urls[@]}" --repos "${repos[@]}" || return 1
            else
                nds_git_wizard_menu_new_key "${urls[@]}" || return 1
            fi
            ;;
        retry) return 0 ;;
        skip) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Closure route menu when account key does not cover all inputs.
# Arguments:
# - failed: <String...> URLs still missing access
# Returns:
# - 0 action done, 1 retry menu, 2 skip
nds_git_wizard_route_menu_closure_account() {
    local -a failed=("$@")
    local -a gh_repos=()
    local choice

    mapfile -t gh_repos < <(nds_git_urls_to_github_repos "${failed[@]}")
    nds_cfg_section_title "Account key — repositories still blocked"
    nds_ui_b "Grant your machine GitHub user access to each repo below,"
    nds_ui_b "or add a read-only deploy key per repository."
    nds_ui_b ""
    nds_cfg_ask_numbered_choice GIT_CLOSURE_ROUTE \
        "retry|deploy|import|skip" \
        "retry=Re-check SSH access (after updating GitHub permissions)|deploy=Add read-only deploy keys for missing repos|import=Import a different SSH key|skip=Skip — continue anyway (install may fail)" \
        "retry"

    choice="$(nds_cfg_get GIT_CLOSURE_ROUTE)"
    case "$choice" in
        deploy)
            nds_git_wizard_register_deploy_for_urls "${failed[@]}" || return 1
            ;;
        import)
            nds_git_wizard_menu_import "${failed[@]}" || return 1
            ;;
        retry) return 0 ;;
        skip) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Closure route menu — deploy keys for missing flake inputs.
# Arguments:
# - failed: <String...> URLs still missing access
# Returns:
# - 0 action done, 1 retry menu, 2 skip
nds_git_wizard_route_menu_closure() {
    local -a failed=("$@")
    local -a gh_repos=()
    local choice

    mapfile -t gh_repos < <(nds_git_urls_to_github_repos "${failed[@]}")
    nds_cfg_section_title "Missing flake git inputs"
    nds_cfg_ask_numbered_choice GIT_CLOSURE_ROUTE \
        "deploy|import|retry|skip" \
        "deploy=Add read-only deploy keys for missing repos|import=Import an existing SSH key|retry=Re-check SSH access|skip=Skip — continue anyway (install may fail)" \
        "deploy"

    choice="$(nds_cfg_get GIT_CLOSURE_ROUTE)"
    case "$choice" in
        deploy)
            nds_git_wizard_register_deploy_for_urls "${failed[@]}" || return 1
            ;;
        import)
            nds_git_wizard_menu_import "${failed[@]}" || return 1
            ;;
        retry) return 0 ;;
        skip) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Wizard step for a single root flake repo.
# Arguments:
# - host:  <String> Git host
# - owner: <String> Repo owner
# - repo:  <String> Repo name
# Returns:
# - 0 action done, 1 retry menu, 2 skip
nds_git_auth_wizard_step_repo() {
    local host="$1" owner="$2" repo="$3"
    local root_url

    root_url="$(_nds_git_to_ssh "$host" "$owner" "$repo")"
    nds_git_wizard_screen_single "$host" "$owner" "$repo"
    nds_git_wizard_route_menu "this repository" "$root_url" --repos "${owner}/${repo}"
}

# Description: Wizard step when flake.lock inputs lack access.
# Arguments:
# - failed: <String...> URLs that failed probe
# Returns:
# - 0 action done, 1 retry menu, 2 skip
nds_git_auth_wizard_step_closure() {
    local -a failed=("$@")
    local mode

    mode="$(nds_git_auth_mode)"
    nds_git_wizard_screen_closure "${failed[@]}"

    if [[ "$mode" == "account" ]]; then
        nds_git_wizard_route_menu_closure_account "${failed[@]}"
        return $?
    fi
    nds_git_wizard_route_menu_closure "${failed[@]}"
    return $?
}

# Compatibility aliases for tests and older callers.
nds_git_auth_prompt_method() { nds_git_wizard_route_menu "$@"; }
nds_git_auth_screen_single() { nds_git_wizard_screen_single "$@"; }
nds_git_auth_screen_closure() { nds_git_wizard_screen_closure "$@"; }
nds_git_auth_resolve_key_display() { nds_git_wizard_resolve_key_display; }
