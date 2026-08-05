#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth gate (orchestrator)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-04
# Description:   Access gates wiring git tools + auth wizard UI
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_GIT_AUTH_SKIP
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_GIT_GH_CLEAR_SKIP

nds_git_access_cleanup_success() {
    nds_git_gh_session_cleanup 2>/dev/null || true
    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
}

# Description: On script stop — if gh is still logged in on this ISO, ask to clear it.
# Runs for any exit path (success, failure, Ctrl+C). Install success already tries
# a silent clear; if that left a session, we still ask.
hook_exit_cleanup() {
    local exit_code="${1:-$?}"
    local logged_in=false

    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true

    if [[ "${NDS_GIT_GH_LEFTOVER:-}" == "true" || "${NDS_GIT_GH_SESSION_ACTIVE:-}" == "true" ]]; then
        logged_in=true
    fi
    if declare -f nds_git_gh_host_logged_in &>/dev/null; then
        nds_git_gh_host_logged_in && logged_in=true
    elif declare -f nds_git_gh_hosts_yml_has_github &>/dev/null; then
        nds_git_gh_hosts_yml_has_github && logged_in=true
    fi

    if [[ "$logged_in" != "true" ]]; then
        nds_install_log "git: exit cleanup — no gh session to clear"
        return 0
    fi

    # Successful install already attempted silent clear — retry once without prompt.
    if [[ "${NDS_GIT_INSTALL_SUCCEEDED:-}" == "true" ]]; then
        nds_git_gh_session_cleanup 2>/dev/null || true
        if declare -f nds_git_gh_host_logged_in &>/dev/null && nds_git_gh_host_logged_in; then
            nds_git_ui_ask_clear_gh_session && nds_git_gh_session_cleanup || true
        fi
        return 0
    fi

    if nds_skip_menu NDS_GIT_GH_CLEAR_SKIP 2>/dev/null; then
        nds_git_gh_session_cleanup 2>/dev/null || true
        return 0
    fi

    nds_ui_b ""
    nds_git_ui_ask_clear_gh_session && nds_git_gh_session_cleanup || true
    return 0
}

# Description: Probe one closure URL; 0 when accessible.
_nds_git_closure_probe_one() {
    local url="$1"
    if nds_git_probe_public "$url" 2>/dev/null; then
        return 0
    fi
    if declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
        return 0
    fi
    nds_git_probe_access "$url"
}

# Description: owner/repo label for a git URL (fallback: ssh form).
_nds_git_closure_repo_label() {
    local url="$1" ssh_url parsed host owner repo
    ssh_url=$(_git_ssh_url "$url")
    if parsed=$(_git_parse "$ssh_url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        printf '%s/%s' "$owner" "$repo"
        return 0
    fi
    printf '%s' "$ssh_url"
}

nds_git_ensure_flake_closure_access() {
    local flake_root="${1:-}" root_url="${2:-}"
    local -a urls=() failed=()
    local url ssh_url rc label pid probe_rc

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

    while true; do
        failed=()
        for url in "${urls[@]}"; do
            label="$(_nds_git_closure_repo_label "$url")"
            if declare -f nds_step_start &>/dev/null; then
                nds_step_start "Checking repository access: ${label}"
                _nds_git_closure_probe_one "$url" &>/dev/null &
                pid=$!
                if declare -f nds_step_spinner &>/dev/null; then
                    nds_step_spinner "$pid" "Checking repository access: ${label}"
                fi
                probe_rc=0
                wait "$pid" || probe_rc=$?
                if [[ "$probe_rc" -eq 0 ]]; then
                    nds_step_complete "Access granted: ${label}"
                    debug "Git access OK: $url"
                else
                    nds_step_fail "No access: ${label}"
                    failed+=("$url")
                fi
            else
                if _nds_git_closure_probe_one "$url"; then
                    success "Access granted: ${label}"
                    debug "Git access OK: $url"
                else
                    failed+=("$url")
                fi
            fi
        done

        if [[ ${#failed[@]} -eq 0 ]]; then
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
    local url="$1"
    local -A cfg=()
    local mode="${NDS_MODE:-interactive}"

    [[ -n "$url" ]] || return 0
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 0 ;;
    esac

    if declare -f nds_mode_resolve &>/dev/null; then
        nds_mode_resolve || true
        mode="${NDS_MODE:-interactive}"
    fi

    if declare -f nds_cfg_aa_from_store &>/dev/null; then
        nds_cfg_aa_from_store cfg
    fi
    cfg[FLAKE_REPO_URL]="$url"

    nds_git_access_run "$mode" cfg || return $?

    if declare -f nds_cfg_aa_to_store &>/dev/null; then
        nds_cfg_aa_to_store cfg
    fi
    return 0
}
