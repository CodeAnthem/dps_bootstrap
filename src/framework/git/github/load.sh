#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub tool loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

nds_git_github_load() {
    local github_dir="${1:?github dir}"
    # Host URL helpers live in standalone/git/hosts.sh (loaded by nds_git_tools_load).
    nds_import_file "${github_dir}/repos.sh" || return 1
    nds_import_file "${github_dir}/gh.sh" || return 1
    nds_import_file "${github_dir}/register.sh" || return 1
    nds_import_file "${github_dir}/deploy.sh" || return 1
    return 0
}
