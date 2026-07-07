#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth gate
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Access gates wiring git tools + auth wizard
# ==================================================================================================

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

    if nds_git_gh_session_active 2>/dev/null; then
        if [[ "$exit_code" -ne 0 ]]; then
            nds_askUserToProceed "Clear gh session on this ISO?" \
                && nds_git_gh_session_cleanup || true
        fi
    fi
    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
}

_nds_git_update_repo_url() {
    local new_url="$1"
    nds_cfg_set FLAKE_REPO_URL "$new_url"
    nds_cfg_set FLAKE_LOCATION "$new_url"
    nds_cfg_set FLAKE_LOCAL_PATH ""
    nds_cfg_set FLAKE_SOURCE "remote"
    export NDS_FLAKE_REPO_URL="$new_url"
    export NDS_FLAKE_SOURCE="remote"
}

# Description: Print owner/repo lines for closure URLs.
_nds_git_log_closure_repo_list() {
    local url ssh_url parsed host owner repo
    nds_ui_h "Git repositories"
    for url in "$@"; do
        ssh_url=$(_nds_git_ssh_url "$url")
        if parsed=$(_nds_git_parse "$ssh_url"); then
            IFS=$'\t' read -r host owner repo <<< "$parsed"
            nds_ui_i "  ${owner}/${repo}"
        else
            nds_ui_i "  ${ssh_url}"
        fi
    done
    nds_ui_b ""
}

# Description: Try import path, session keys, and discovered ~/.ssh keys.
# Arguments:
# - url: <String> Git URL to probe
# Returns:
# - <Bool> 0 when access works with an existing key
_nds_git_auth_try_existing_access() {
    local url="$1"
    local found

    nds_git_auth_try_import_path && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    if nds_git_probe_access "$url"; then
        nds_git_auth_set_mode imported
        return 0
    fi

    nds_git_auth_try_session_key && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    nds_git_keys_load_all || true
    if nds_git_probe_access "$url"; then
        return 0
    fi

    if found="$(nds_git_discover_try_candidates "$url")"; then
        nds_git_auth_set_mode imported
        debug "Git access via discovered key: ${found}"
        return 0
    fi
    return 1
}

nds_git_ensure_flake_closure_access() {
    local flake_root="${1:-}" root_url="${2:-}"
    local -a urls=() failed=()
    local url ssh_url rc

    nds_git_keys_load_all || true

    if [[ -n "$flake_root" && -d "$flake_root" ]]; then
        mapfile -t urls < <(_nds_flake_collect_git_remote_urls "$flake_root" "$root_url")
    elif [[ -n "$root_url" ]]; then
        local lock_file="${NDS_RUNTIME_DIR:-/tmp}/flake_lock_probe/flake.lock"
        if [[ ! -f "$lock_file" ]]; then
            if declare -f nds_step_exec &>/dev/null; then
                nds_step_exec "Fetching flake.lock" \
                    nds_git_fetch_flake_lock "$root_url" "$lock_file" || true
            else
                info "Fetching flake.lock (shallow clone)..."
                nds_git_fetch_flake_lock "$root_url" "$lock_file" || true
            fi
        fi
        mapfile -t urls < <(_nds_flake_collect_git_remote_urls_from_root "$root_url")
    else
        error "Flake root or repo URL required for closure check"
        return 1
    fi

    [[ ${#urls[@]} -gt 0 ]] || return 0

    NDS_GIT_CLOSURE_URLS="$(printf '%s\n' "${urls[@]}")"
    _nds_git_log_closure_repo_list "${urls[@]}"
    log "Checking SSH access to ${#urls[@]} git repository(ies)"

    while true; do
        failed=()
        for url in "${urls[@]}"; do
            if nds_git_probe_public "$url" 2>/dev/null; then
                debug "Public git input: $url"
            elif nds_git_probe_access "$url"; then
                debug "Git access OK: $url"
            else
                failed+=("$url")
            fi
        done

        if [[ ${#failed[@]} -eq 0 ]]; then
            success "SSH access confirmed for all ${#urls[@]} repository(ies)."
            nds_install_log "git: closure access OK (${#urls[@]} repos)"
            return 0
        fi

        for url in "${failed[@]}"; do
            ssh_url=$(_nds_git_ssh_url "$url")
            nds_install_log "git: no access — ${ssh_url}"
        done

        if nds_skip_menu NDS_GIT_AUTH_SKIP; then
            error "Cannot verify SSH access to all flake git inputs"
            return 1
        fi

        nds_git_auth_wizard_step_closure "${failed[@]}" || continue
        rc=$?
        [[ "$rc" -eq 2 ]] && {
            warn "Continuing without SSH access to every flake input — install may fail."
            return 0
        }
        nds_git_keys_load_all || true
    done
}

nds_git_ensure_access() {
    local url="$1" parsed host="" owner="" repo="" rc

    [[ -n "$url" ]] || return 0
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 0 ;;
    esac

    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$url" != git@* && "$url" != ssh://* ]]; then
            _nds_git_update_repo_url "$(_nds_git_to_ssh "$host" "$owner" "$repo")"
            url="$(nds_cfg_get FLAKE_REPO_URL)"
        fi
    fi

    if nds_git_probe_public "$url" 2>/dev/null; then
        success "Public repository ${owner}/${repo} — no SSH key required."
        nds_install_log "git: public repo ${owner}/${repo}"
        return 0
    fi

    if _nds_git_auth_try_existing_access "$url"; then
        success "Git access confirmed for ${owner}/${repo} (existing key)."
        return 0
    fi

    if nds_skip_menu NDS_GIT_AUTH_SKIP; then
        warn "Auto-skip on — continuing without interactive git auth (clone may fail)."
        return 0
    fi

    while true; do
        nds_git_auth_wizard_step_repo "$host" "$owner" "$repo" || continue
        rc=$?
        [[ "$rc" -eq 2 ]] && {
            warn "Continuing without configured git auth — the clone may fail."
            return 0
        }

        url="$(nds_cfg_get FLAKE_REPO_URL)"
        [[ -z "$url" ]] && url="$(_nds_git_to_ssh "$host" "$owner" "$repo")"
        nds_git_keys_load_all || true

        if nds_git_probe_access "$url"; then
            success "Git access confirmed for ${owner}/${repo}."
            return 0
        fi
        warn "Still no access — register a deploy key on ${owner}/${repo} or import a working key."
        nds_ui_i "Deploy keys: github.com/${owner}/${repo}/settings/keys"
    done
}
