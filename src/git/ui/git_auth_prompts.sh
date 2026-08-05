#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth prompts (interactive refine of config AA)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Wizard UI; syncs GIT_* / FLAKE_* keys back into config AA
# ==================================================================================================

# Description: Run repo auth wizard and copy results into cfg AA.
# Arguments:
# - cfg: <Nameref> Config AA (needs GIT_ACCESS_HOST/OWNER/REPO or FLAKE_REPO_URL)
# Returns:
# - wizard status (0 ok, NDS_ACTION_BACK, or failure)
nds_git_auth_prompts() {
    local -n _g_p=$1
    local host owner repo url method

    host="${_g_p[GIT_ACCESS_HOST]:-}"
    owner="${_g_p[GIT_ACCESS_OWNER]:-}"
    repo="${_g_p[GIT_ACCESS_REPO]:-}"
    if [[ -z "$host" || -z "$owner" || -z "$repo" ]]; then
        error "Git auth prompts need host/owner/repo in config AA"
        return 1
    fi

    # Transitional: wizard still reads/writes settings store — sync AA first.
    if declare -f nds_cfg_aa_to_store &>/dev/null; then
        nds_cfg_aa_to_store _g_p
    fi

    nds_git_auth_wizard_step_repo "$host" "$owner" "$repo"
    local rc=$?
    [[ "$rc" -ne 0 ]] && return "$rc"

    if declare -f nds_cfg_aa_from_store &>/dev/null; then
        nds_cfg_aa_from_store _g_p
    fi

    url="${_g_p[FLAKE_REPO_URL]:-}"
    [[ -z "$url" ]] && url="$(_git_to_ssh "$host" "$owner" "$repo")"
    _g_p[FLAKE_REPO_URL]="$url"

    method="$(nds_cfg_get GIT_SSH_KEY_REGISTER_METHOD 2>/dev/null || true)"
    [[ -z "$method" ]] && method="$(nds_cfg_get GIT_SSH_KEY_TYPE 2>/dev/null || true)"
    [[ -n "$method" ]] && _g_p[GIT_ACCESS_METHOD]="$method"
    return 0
}
