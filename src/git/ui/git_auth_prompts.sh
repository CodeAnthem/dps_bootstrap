#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth prompts (interactive)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Wizard UI only — caller syncs config AA to/from store around this call
# ==================================================================================================

# Description: Run repo auth wizard for host/owner/repo from cfg AA.
nds_git_auth_prompts() {
    local -n _g_p=$1
    local host="${_g_p[GIT_ACCESS_HOST]:-}"
    local owner="${_g_p[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_p[GIT_ACCESS_REPO]:-}"

    if [[ -z "$host" || -z "$owner" || -z "$repo" ]]; then
        error "Git auth prompts need GIT_ACCESS_HOST/OWNER/REPO in config AA"
        return 1
    fi

    nds_git_auth_wizard_step_repo "$host" "$owner" "$repo"
}
