#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access feature entry (mode + config AA)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Feature entry; may open GH/wizard UI from feature-local policy
# ==================================================================================================

# Description: Ensure SSH access using mode + config AA (mutates AA).
# Arguments:
# - mode: <String> interactive | unattended
# - cfg:  <Nameref> Full config AA
nds_git_access_run() {
    local mode="${1:-interactive}"
    local -n _g_run=$2
    local url owner repo rc

    nds_git_access_logic_normalize _g_run || return 0
    url="${_g_run[FLAKE_REPO_URL]:-}"
    owner="${_g_run[GIT_ACCESS_OWNER]:-}"
    repo="${_g_run[GIT_ACCESS_REPO]:-}"

    # Keep legacy store in sync for helpers that still read nds_cfg_*
    if declare -f nds_cfg_aa_to_store &>/dev/null; then
        nds_cfg_aa_to_store _g_run
        if declare -f _git_update_repo_url &>/dev/null; then
            _git_update_repo_url "$url"
        fi
    fi

    if nds_git_access_logic_try _g_run; then
        return 0
    fi

    if nds_skip_menu NDS_GIT_AUTH_SKIP 2>/dev/null; then
        error "Private repo ${owner}/${repo} needs SSH access (unset NDS_GIT_AUTH_SKIP and configure a key)"
        return 1
    fi

    # Feature-local: unattended may still open UI for GH device / wizard when needed.
    if [[ "$mode" == "unattended" ]] && ! nds_git_access_wants_gh_ui _g_run; then
        error "Unattended git access failed for ${owner}/${repo} — provide working keys or GIT_* method=gh"
        return 1
    fi

    while true; do
        nds_git_auth_prompts _g_run
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && continue

        if nds_git_access_logic_verify _g_run; then
            if declare -f nds_git_access_set &>/dev/null; then
                nds_git_access_set method "${_g_run[FLAKE_REPO_URL]}" \
                    "${_g_run[GIT_ACCESS_METHOD]:-import}"
            fi
            return 0
        fi
        warn "Still no access — register a key on ${owner}/${repo} or import a working key."
        if nds_git_host_is_github "${_g_run[GIT_ACCESS_HOST]:-}" 2>/dev/null; then
            nds_ui_i "Deploy keys: https://github.com/${owner}/${repo}/settings/keys"
        fi
        if [[ "$mode" == "unattended" ]] && ! nds_git_access_wants_gh_ui _g_run; then
            return 1
        fi
    done
}
