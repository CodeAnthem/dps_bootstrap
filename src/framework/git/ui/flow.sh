#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard flow (menu state machine)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-03
# ==================================================================================================

# Description: Top-level route menu for a private git URL (GitHub vs generic).
# No skip — private access is required. Supports 0=back.
# Arguments:
# - scope_label: <String> e.g. this repository
# - urls:        <String...> URLs to probe
# - --repos:     <String...> owner/repo for gh (optional)
# Returns:
# - 0 action done, 1 retry menu, NDS_ACTION_BACK go back
nds_git_wizard_route_menu() {
    local scope_label="$1"
    shift
    local -a urls=() repos=()
    local choice parsing_repos=false arg host="" is_gh=false rc

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

    if [[ ${#urls[@]} -gt 0 ]]; then
        host="$(_git_parse "${urls[0]}" 2>/dev/null | cut -f1)" || host=""
        nds_git_host_is_github "$host" 2>/dev/null && is_gh=true
    fi

    nds_cfg_section_title "What do you want to do? (${scope_label})"

    if [[ "$is_gh" == "true" ]]; then
        nds_cfg_ask_numbered_choice GIT_AUTH_ROUTE \
            "import|gh|manual|retry" \
            "import=I already have a key — scan cwd and ~/.ssh, or pick a path|gh=Use gh CLI (device login)|manual=Create a key and register on github.com yourself|retry=Re-check SSH access (no key change)" \
            "import" \
            true
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

        choice="$(nds_cfg_get GIT_AUTH_ROUTE)"
        case "$choice" in
            import)
                nds_git_wizard_menu_import "${urls[@]}" || return 1
                ;;
            gh)
                nds_cfg_set GIT_SSH_KEY_REGISTER_METHOD gh
                info "GitHub CLI route selected — caching gh binary if needed..."
                nds_git_gh_ensure_prefetch || {
                    error "Could not prepare gh CLI (nixpkgs#gh)"
                    return 1
                }
                if [[ ${#repos[@]} -gt 0 ]]; then
                    nds_git_wizard_menu_new_key "${urls[@]}" --repos "${repos[@]}" || return 1
                else
                    nds_git_wizard_menu_new_key "${urls[@]}" || return 1
                fi
                ;;
            manual)
                nds_cfg_set GIT_SSH_KEY_REGISTER_METHOD manual
                if [[ ${#repos[@]} -gt 0 ]]; then
                    nds_git_wizard_menu_new_key "${urls[@]}" --repos "${repos[@]}" || return 1
                else
                    nds_git_wizard_menu_new_key "${urls[@]}" || return 1
                fi
                ;;
            retry) return 0 ;;
            *) return 1 ;;
        esac
    else
        nds_cfg_ask_numbered_choice GIT_AUTH_ROUTE \
            "import|new|retry" \
            "import=I already have a key — scan cwd and ~/.ssh, or pick a path|new=Create a new SSH key (manual register)|retry=Re-check SSH access (no key change)" \
            "import" \
            true
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

        choice="$(nds_cfg_get GIT_AUTH_ROUTE)"
        case "$choice" in
            import)
                nds_git_wizard_menu_import "${urls[@]}" || return 1
                ;;
            new)
                nds_cfg_set GIT_SSH_KEY_REGISTER_METHOD manual
                nds_git_wizard_menu_new_key "${urls[@]}" || return 1
                ;;
            retry) return 0 ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

# Description: Closure route when account key does not cover all inputs.
# Arguments:
# - failed: <String...> URLs still missing access
# Returns:
# - 0 done, 1 retry, NDS_ACTION_BACK back
nds_git_wizard_route_menu_closure_account() {
    local -a failed=("$@")
    local choice rc

    nds_cfg_section_title "Account key — repositories still blocked"
    nds_ui_b "Grant your machine GitHub user access to each repo below,"
    nds_ui_b "or add a read-only deploy key per repository."
    nds_ui_b ""
    nds_cfg_ask_numbered_choice GIT_CLOSURE_ROUTE \
        "retry|deploy|import" \
        "retry=Re-check SSH access (after updating GitHub permissions)|deploy=Add read-only deploy keys for missing repos|import=Import a different SSH key" \
        "retry" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    choice="$(nds_cfg_get GIT_CLOSURE_ROUTE)"
    case "$choice" in
        deploy)
            nds_git_wizard_register_deploy_for_urls "${failed[@]}" || return 1
            ;;
        import)
            nds_git_wizard_menu_import "${failed[@]}" || return 1
            ;;
        retry) return 0 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Closure route — deploy/import for missing flake inputs (no skip).
nds_git_wizard_route_menu_closure() {
    local -a failed=("$@")
    local choice rc first_host is_gh=false

    if [[ ${#failed[@]} -gt 0 ]]; then
        first_host="$(_git_parse "${failed[0]}" 2>/dev/null | cut -f1)" || first_host=""
        nds_git_host_is_github "$first_host" 2>/dev/null && is_gh=true
    fi

    nds_cfg_section_title "Missing flake git inputs"
    if [[ "$is_gh" == "true" ]]; then
        nds_cfg_ask_numbered_choice GIT_CLOSURE_ROUTE \
            "deploy|import|gh|retry" \
            "deploy=Add read-only deploy keys for missing repos|import=Import an existing SSH key|gh=Use gh CLI for missing repos|retry=Re-check SSH access" \
            "deploy" \
            true
    else
        nds_cfg_ask_numbered_choice GIT_CLOSURE_ROUTE \
            "deploy|import|retry" \
            "deploy=Add read-only deploy keys for missing repos|import=Import an existing SSH key|retry=Re-check SSH access" \
            "deploy" \
            true
    fi
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    choice="$(nds_cfg_get GIT_CLOSURE_ROUTE)"
    case "$choice" in
        deploy)
            nds_git_wizard_register_deploy_for_urls "${failed[@]}" || return 1
            ;;
        import)
            nds_git_wizard_menu_import "${failed[@]}" || return 1
            ;;
        gh)
            nds_cfg_set GIT_SSH_KEY_REGISTER_METHOD gh
            nds_git_wizard_register_deploy_for_urls "${failed[@]}" || return 1
            ;;
        retry) return 0 ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Wizard step for a single root flake repo.
nds_git_auth_wizard_step_repo() {
    local host="$1" owner="$2" repo="$3"
    local root_url

    root_url="$(_git_to_ssh "$host" "$owner" "$repo")"
    nds_git_wizard_screen_single "$host" "$owner" "$repo"
    nds_git_wizard_route_menu "this repository" "$root_url" --repos "${owner}/${repo}"
}

# Description: Wizard step when flake.lock inputs lack access.
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
