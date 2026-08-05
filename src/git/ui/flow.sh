#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard flow (menu state machine)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-05
# Description:   Persist-access + strategy menus; AA-bound asks via nds_aa_ask_*
# ==================================================================================================

# Description: Ask whether the installed machine should keep private-git SSH access.
nds_git_wizard_ask_persist_access() {
    local existing rc
    existing="$(nds_feat_cfg_get GIT_PERSIST_ACCESS 2>/dev/null || true)"
    if [[ "$existing" == "true" || "$existing" == "false" ]]; then
        return 0
    fi

    nds_cfg_section_title "Keep repository access on the installed machine?"
    nds_ui_b "Yes: install SSH keys on the target so it can fetch private flakes later."
    nds_ui_b "No:  access only for this live-ISO install (keys stay on the ISO)."
    nds_ui_b ""
    nds_aa_ask_numbered_choice GIT_PERSIST_ACCESS \
        "yes|no" \
        "yes=Keep access on the installed machine|no=Install-time access only (do not copy keys to the machine)" \
        "yes" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    if [[ "$(nds_feat_cfg_get GIT_PERSIST_ACCESS)" == "yes" ]]; then
        nds_feat_cfg_set GIT_PERSIST_ACCESS "true"
    else
        nds_feat_cfg_set GIT_PERSIST_ACCESS "false"
    fi
    return 0
}

# Description: True when GIT_PERSIST_ACCESS is enabled (default true if unset).
nds_git_persist_access() {
    local v
    v="$(nds_feat_cfg_get GIT_PERSIST_ACCESS 2>/dev/null || true)"
    [[ -z "$v" || "$v" == "true" || "$v" == "yes" ]]
}

# Description: Ask how to obtain access for private repos (path | gh | generate).
# Arguments:
# - scope_label: <String> Menu subtitle
# - is_gh:       <Bool>   GitHub host (adds gh option)
# Returns:
# - Sets GIT_AUTH_ROUTE; NDS_ACTION_BACK on back
nds_git_wizard_ask_auth_method() {
    local scope_label="$1" is_gh="$2"
    local rc

    nds_cfg_section_title "How do you want to authenticate? (${scope_label})"
    if [[ "$is_gh" == "true" ]]; then
        nds_aa_ask_numbered_choice GIT_AUTH_ROUTE \
            "path|gh|generate" \
            "path=Provide a private SSH key path|gh=Use gh CLI (device login)|generate=Create a key and register on github.com yourself" \
            "gh" \
            true
    else
        nds_aa_ask_numbered_choice GIT_AUTH_ROUTE \
            "path|generate" \
            "path=Provide a private SSH key path|generate=Create a key and register on the forge yourself" \
            "generate" \
            true
    fi
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    return 0
}

# Description: Ask key strategy when keeping access on the installed machine.
nds_git_wizard_ask_access_strategy() {
    local existing rc
    existing="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY 2>/dev/null || true)"
    if [[ -n "$existing" ]]; then
        return 0
    fi

    nds_cfg_section_title "SSH key strategy (kept on the machine)"
    nds_ui_b "Deploy key: read-only, one key per repository."
    nds_ui_b "Account key: one key on a dedicated GitHub user (full account SSH access)."
    nds_ui_b ""
    nds_aa_ask_numbered_choice GIT_ACCESS_STRATEGY \
        "deploy-this|account-this|deploy-all|account-all" \
        "deploy-this=Deploy key (this repository only)|account-this=Account key (this repository only)|deploy-all=Deploy keys (all related repos under the same owner)|account-all=Account key (all related repos under the same owner)" \
        "deploy-all" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    return 0
}

# Description: Run path/gh/generate for the current strategy and URL set.
# Arguments:
# - urls:    <String...> Probe URLs
# - --repos: <String...> owner/repo for gh (optional)
nds_git_wizard_execute_auth_choice() {
    local -a urls=() repos=()
    local choice strategy method parsing_repos=false arg

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

    choice="$(nds_feat_cfg_get GIT_AUTH_ROUTE)"
    strategy="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY)"
    [[ -n "$strategy" ]] || strategy="deploy-this"

    case "$choice" in
        path|import)
            nds_git_wizard_menu_import_path "${urls[@]}" || return 1
            ;;
        gh)
            nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD gh
            nds_git_gh_ensure_prefetch || {
                error "Could not prepare gh CLI (nixpkgs#gh)"
                return 1
            }
            case "$strategy" in
                account-this|account-all)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE account
                    if [[ ${#repos[@]} -gt 0 ]]; then
                        nds_git_wizard_menu_gh_account "${repos[@]}" || return 1
                    else
                        nds_git_wizard_menu_gh_account || return 1
                    fi
                    ;;
                *)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                    nds_git_wizard_register_deploy_for_urls "${urls[@]}" || return 1
                    ;;
            esac
            ;;
        generate|manual|new)
            nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD manual
            case "$strategy" in
                account-this|account-all)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE account
                    if [[ ${#repos[@]} -gt 0 ]]; then
                        nds_git_wizard_register_account "${repos[@]}" || return 1
                    else
                        nds_git_wizard_register_account || return 1
                    fi
                    ;;
                *)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                    nds_git_wizard_register_deploy_for_urls "${urls[@]}" || return 1
                    ;;
            esac
            ;;
        *) return 1 ;;
    esac
    return 0
}

# Description: Top-level route menu for a private git URL (GitHub vs generic).
# No skip / no retry — private access is required. Supports 0=back.
# Arguments:
# - scope_label: <String> e.g. this repository
# - urls:        <String...> URLs to probe
# - --repos:     <String...> owner/repo for gh (optional)
# Returns:
# - 0 action done, 1 failure, NDS_ACTION_BACK go back
nds_git_wizard_route_menu() {
    local scope_label="$1"
    shift
    local -a urls=() repos=()
    local parsing_repos=false arg host="" is_gh=false rc

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

    nds_git_wizard_ask_persist_access
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    if nds_git_persist_access; then
        nds_git_wizard_ask_access_strategy
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    else
        # Ephemeral install-time access: deploy keys for needed repos, not copied to target.
        [[ -z "$(nds_feat_cfg_get GIT_ACCESS_STRATEGY)" ]] && nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-all"
    fi

    nds_git_wizard_ask_auth_method "$scope_label" "$is_gh"
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    if [[ ${#repos[@]} -gt 0 ]]; then
        nds_git_wizard_execute_auth_choice "${urls[@]}" --repos "${repos[@]}"
    else
        nds_git_wizard_execute_auth_choice "${urls[@]}"
    fi
}

# Description: Owner from a git URL (stdout).
_git_wizard_url_owner() {
    local url="$1" parsed
    parsed=$(_git_parse "$(_git_ssh_url "$url")") || return 1
    printf '%s\n' "$(cut -f2 <<<"$parsed")"
}

# Description: Closure route when account key does not cover all inputs.
nds_git_wizard_route_menu_closure_account() {
    local -a failed=("$@")
    local choice rc is_gh=false first_host

    if [[ ${#failed[@]} -gt 0 ]]; then
        first_host="$(_git_parse "${failed[0]}" 2>/dev/null | cut -f1)" || first_host=""
        nds_git_host_is_github "$first_host" 2>/dev/null && is_gh=true
    fi

    nds_cfg_section_title "Account key — repositories still blocked"
    nds_ui_b "Grant your machine GitHub user access to each repo below,"
    nds_ui_b "or add a read-only deploy key per repository."
    nds_ui_b ""

    nds_git_wizard_ask_auth_method "missing repositories" "$is_gh"
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    # Prefer deploy keys for remaining blocked repos under account strategy.
    nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-this"
    nds_git_wizard_execute_auth_choice "${failed[@]}"
}

# Description: Closure route — apply strategy or re-auth for missing flake inputs.
nds_git_wizard_route_menu_closure() {
    local -a failed=("$@") same_owner=() other=()
    local strategy owner root_owner url is_gh=false first_host rc

    strategy="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY)"
    [[ -n "$strategy" ]] || strategy="deploy-this"

    if [[ ${#failed[@]} -gt 0 ]]; then
        first_host="$(_git_parse "${failed[0]}" 2>/dev/null | cut -f1)" || first_host=""
        nds_git_host_is_github "$first_host" 2>/dev/null && is_gh=true
        root_owner="$(_git_wizard_url_owner "${failed[0]}")" || root_owner=""
    fi

    # deploy-all / account-all: auto-handle same-owner failures when method already chosen.
    if [[ "$strategy" == "deploy-all" || "$strategy" == "account-all" ]]; then
        for url in "${failed[@]}"; do
            owner="$(_git_wizard_url_owner "$url")" || owner=""
            if [[ -n "$root_owner" && "$owner" == "$root_owner" ]]; then
                same_owner+=("$url")
            else
                other+=("$url")
            fi
        done

        if [[ ${#same_owner[@]} -gt 0 ]]; then
            case "$strategy" in
                deploy-all)
                    info "Applying deploy keys for ${#same_owner[@]} related repositories..."
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                    if [[ "$(nds_feat_cfg_get GIT_SSH_KEY_REGISTER_METHOD)" == "gh" ]]; then
                        nds_git_gh_ensure_prefetch || true
                    fi
                    nds_git_wizard_register_deploy_for_urls "${same_owner[@]}" || return 1
                    ;;
                account-all)
                    # Account key should already cover same-owner; re-probe after brief wait.
                    warn "Account key still missing access to ${#same_owner[@]} repo(s) under ${root_owner}."
                    nds_ui_i "Grant collaborator/org access, then continue — or switch to deploy keys."
                    nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-this"
                    nds_git_wizard_ask_auth_method "missing repositories" "$is_gh" || return 1
                    nds_git_wizard_execute_auth_choice "${same_owner[@]}" || return 1
                    ;;
            esac
        fi

        if [[ ${#other[@]} -eq 0 ]]; then
            return 0
        fi
        failed=("${other[@]}")
        nds_feat_cfg_set GIT_ACCESS_STRATEGY ""
    fi

    nds_cfg_section_title "Missing flake git inputs"
    nds_git_wizard_ask_persist_access
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    if nds_git_persist_access; then
        nds_feat_cfg_set GIT_ACCESS_STRATEGY ""
        nds_git_wizard_ask_access_strategy
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    else
        nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-all"
    fi

    nds_git_wizard_ask_auth_method "missing repositories" "$is_gh"
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    nds_git_wizard_execute_auth_choice "${failed[@]}"
}

# Description: Bind a temporary AA from store when wizard runs outside a feature entry.
_nds_git_wizard_ensure_aa() {
    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        _NDS_GIT_WIZ_AA_OWNED=false
        return 0
    fi
    declare -gA _NDS_GIT_WIZ_AA=()
    nds_cfg_aa_from_store _NDS_GIT_WIZ_AA
    nds_cfg_aa_bind _NDS_GIT_WIZ_AA
    _NDS_GIT_WIZ_AA_OWNED=true
}

_nds_git_wizard_release_aa() {
    if [[ "${_NDS_GIT_WIZ_AA_OWNED:-false}" == "true" ]]; then
        nds_cfg_aa_to_store _NDS_GIT_WIZ_AA
        nds_cfg_aa_unbind
        _NDS_GIT_WIZ_AA_OWNED=false
    fi
}

# Description: Wizard step for a single root flake repo.
nds_git_auth_wizard_step_repo() {
    local host="$1" owner="$2" repo="$3"
    local root_url rc=0

    _nds_git_wizard_ensure_aa
    root_url="$(_git_to_ssh "$host" "$owner" "$repo")"
    nds_git_wizard_screen_single "$host" "$owner" "$repo"
    nds_git_wizard_route_menu "this repository" "$root_url" --repos "${owner}/${repo}" || rc=$?
    _nds_git_wizard_release_aa
    return "$rc"
}

# Description: Wizard step when flake.lock inputs lack access.
nds_git_auth_wizard_step_closure() {
    local -a failed=("$@")
    local mode rc=0

    _nds_git_wizard_ensure_aa
    mode="$(nds_git_auth_mode)"
    nds_git_wizard_screen_closure "${failed[@]}"

    if [[ "$mode" == "account" ]]; then
        nds_git_wizard_route_menu_closure_account "${failed[@]}" || rc=$?
    else
        nds_git_wizard_route_menu_closure "${failed[@]}" || rc=$?
    fi
    _nds_git_wizard_release_aa
    return "$rc"
}
