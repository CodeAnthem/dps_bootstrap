#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth gate
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Access gates wiring git tools + auth wizard
# ==================================================================================================

# Description: Clear gh session after successful install.
nds_git_access_cleanup_success() {
    nds_git_gh_session_cleanup 2>/dev/null || true
    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
}

# Description: Legacy alias — prefer nds_git_access_cleanup_success on install success.
nds_git_access_cleanup() {
    nds_git_access_cleanup_success
}

# Description: Exit hook — prompt to clear gh session on abort; never auto-clear on failure.
# Arguments:
# - exit_code: <Int|optional> Process exit code (defaults to $?)
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

nds_git_ensure_flake_closure_access() {
    local flake_root="$1" root_url="${2:-}"
    local -a urls=() failed=()
    local url ssh_url rc

    [[ -d "$flake_root" ]] || { error "Flake root not found: $flake_root"; return 1; }

    nds_git_auth_try_import_path || true
    nds_git_auth_try_session_key || true

    mapfile -t urls < <(_nds_flake_collect_git_remote_urls "$flake_root" "$root_url")
    [[ ${#urls[@]} -gt 0 ]] || return 0

    NDS_GIT_CLOSURE_URLS="$(printf '%s\n' "${urls[@]}")"
    log "Checking SSH access to ${#urls[@]} flake git input(s)"

    while true; do
        failed=()
        for url in "${urls[@]}"; do
            if nds_git_probe_access "$url"; then
                debug "Git access OK: $url"
            else
                failed+=("$url")
            fi
        done

        if [[ ${#failed[@]} -eq 0 ]]; then
            success "SSH access confirmed for all ${#urls[@]} flake git input(s)."
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

    nds_git_auth_try_import_path || true
    nds_git_auth_try_session_key || true

    if nds_git_probe_access "$url"; then
        debug "Git access OK: $url"
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

        if nds_git_probe_access "$url"; then
            success "Git access confirmed."
            return 0
        fi
        warn "Still no access — register the SSH key on your git host or import a key that already has access."
        nds_ui_i "Session key: $(nds_git_session_pubkey_path 2>/dev/null || echo unknown)"
        nds_ui_i "Try: gh (GitHub account key), manual registration, or remove old keys titled $(nds_git_ssh_key_title 2>/dev/null || echo nds-*) on GitHub."
    done
}
