#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth gate (orchestrator)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-31
# Description:   Access gates wiring git tools + auth wizard UI
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_GIT_AUTH_SKIP

nds_git_access_cleanup_success() {
    nds_git_gh_session_cleanup 2>/dev/null || true
    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
}

nds_git_access_cleanup() {
    nds_git_access_cleanup_success
}

hook_exit_cleanup() {
    local exit_code="${1:-$?}"

    if [[ "${NDS_GIT_INSTALL_SUCCEEDED:-}" == "true" ]]; then
        unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
        return 0
    fi

    if [[ "${NDS_GIT_GH_SESSION_ACTIVE:-}" == "true" ]]; then
        if [[ "$exit_code" -ne 0 ]]; then
            nds_git_ui_ask_clear_gh_session && nds_git_gh_session_cleanup || true
        fi
    fi
    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
}

# Description: Public entry — ensure SSH access to a git URL (and optional flags).
# Private repos cannot be skipped; maps / discovery / wizard until probe succeeds.
# Arguments:
# - url: <String> Git URL
nds_git_access_gate() {
    local url="$1"
    nds_git_ensure_access "$url"
}

nds_git_ensure_flake_closure_access() {
    local flake_root="${1:-}" root_url="${2:-}"
    local -a urls=() failed=()
    local url ssh_url rc

    nds_git_keys_load_all || true

    if [[ -n "$flake_root" && -d "$flake_root" ]]; then
        mapfile -t urls < <(_flake_collect_git_remote_urls "$flake_root" "$root_url")
    elif [[ -n "$root_url" ]]; then
        if [[ ! -f "${NDS_FLAKE_PROBE_REPO:-}/flake.nix" ]]; then
            if declare -f nds_step_exec &>/dev/null; then
                nds_step_exec "Cloning flake repository" \
                    nds_git_clone_flake_probe "$root_url" || true
            else
                info "Cloning flake repository..."
                nds_git_clone_flake_probe "$root_url" || true
            fi
        fi
        mapfile -t urls < <(_flake_collect_git_remote_urls_from_root "$root_url")
    else
        error "Flake root or repo URL required for closure check"
        return 1
    fi

    [[ ${#urls[@]} -gt 0 ]] || return 0

    NDS_GIT_CLOSURE_URLS="$(printf '%s\n' "${urls[@]}")"
    nds_git_ui_log_closure_repo_list "${urls[@]}"
    log "Checking SSH access to ${#urls[@]} git repository(ies)"

    while true; do
        failed=()
        for url in "${urls[@]}"; do
            if nds_git_probe_public "$url" 2>/dev/null; then
                debug "Public git input: $url"
            elif declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
                debug "Git access OK (map): $url"
            elif nds_git_probe_access "$url"; then
                debug "Git access OK: $url"
            else
                failed+=("$url")
            fi
        done

        if [[ ${#failed[@]} -eq 0 ]]; then
            success "SSH access confirmed for all ${#urls[@]} repository(ies)."
            nds_install_log "git: closure access OK (${#urls[@]} repos)"
            nds_git_access_mark_verified
            return 0
        fi

        for url in "${failed[@]}"; do
            ssh_url=$(_git_ssh_url "$url")
            nds_install_log "git: no access — ${ssh_url}"
        done

        # Soft env skip removed for private closure — fail hard if skip requested
        if nds_skip_menu NDS_GIT_AUTH_SKIP; then
            error "Cannot verify SSH access to all flake git inputs (NDS_GIT_AUTH_SKIP set — unset it and configure keys)"
            return 1
        fi

        nds_git_auth_wizard_step_closure "${failed[@]}"
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && continue
        nds_git_keys_load_all || true
        nds_git_ssh_config_refresh || true
    done
}

nds_git_ensure_access() {
    local url="$1" parsed host="" owner="" repo="" rc norm

    [[ -n "$url" ]] || return 0
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 0 ;;
    esac

    if parsed=$(_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$url" != git@* && "$url" != ssh://* ]]; then
            _git_update_repo_url "$(_git_to_ssh "$host" "$owner" "$repo")"
            url="$(nds_cfg_get FLAKE_REPO_URL)"
        fi
    fi

    if nds_git_probe_public "$url" 2>/dev/null; then
        success "Public repository ${owner}/${repo} — no SSH key required."
        nds_install_log "git: public repo ${owner}/${repo}"
        nds_git_access_mark_verified
        return 0
    fi

    if declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
        success "Git access confirmed for ${owner}/${repo} (configured map)."
        nds_git_access_mark_verified
        return 0
    fi

    if _git_auth_try_existing_access "$url"; then
        success "Git access confirmed for ${owner}/${repo} (existing key)."
        nds_git_access_mark_verified
        if declare -f nds_git_access_set_method &>/dev/null; then
            nds_git_access_set_method "$url" "import"
        fi
        return 0
    fi

    if nds_skip_menu NDS_GIT_AUTH_SKIP; then
        error "Private repo ${owner}/${repo} needs SSH access (unset NDS_GIT_AUTH_SKIP and configure a key)"
        return 1
    fi

    while true; do
        nds_git_auth_wizard_step_repo "$host" "$owner" "$repo"
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && continue

        url="$(nds_cfg_get FLAKE_REPO_URL)"
        [[ -z "$url" ]] && url="$(_git_to_ssh "$host" "$owner" "$repo")"
        nds_git_keys_load_all || true

        if nds_git_probe_access "$url"; then
            success "Git access confirmed for ${owner}/${repo}."
            nds_git_access_mark_verified
            if declare -f nds_git_access_set_method &>/dev/null; then
                nds_git_access_set_method "$url" "$(nds_cfg_get GIT_SSH_KEY_REGISTER_METHOD)"
                [[ -z "$(nds_git_access_get_method "$url")" ]] && \
                    nds_git_access_set_method "$url" "$(nds_cfg_get GIT_SSH_KEY_TYPE)"
            fi
            return 0
        fi
        warn "Still no access — register a key on ${owner}/${repo} or import a working key."
        if nds_git_host_is_github "$host" 2>/dev/null; then
            nds_ui_i "Deploy keys: https://github.com/${owner}/${repo}/settings/keys"
        fi
    done
}
