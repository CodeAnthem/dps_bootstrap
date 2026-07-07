#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Load git tool modules (logic + wizard menus)
# ==================================================================================================

nds_git_tools_load() {
    [[ "${NDS_GIT_TOOLS_LOADED:-false}" == "true" ]] && return 0
    local tools_dir="${1:?tools dir}"
    nds_import_file "${tools_dir}/url.sh" || return 1
    nds_import_file "${tools_dir}/ssh.sh" || return 1
    nds_import_file "${tools_dir}/probe.sh" || return 1
    nds_import_file "${tools_dir}/closure.sh" || return 1
    nds_import_file "${tools_dir}/key.sh" || return 1
    nds_import_file "${tools_dir}/keys.sh" || return 1
    nds_import_file "${tools_dir}/qr.sh" || return 1
    nds_import_file "${tools_dir}/discover.sh" || return 1
    nds_import_file "${tools_dir}/github/load.sh" || return 1
    nds_git_github_load "${tools_dir}/github" || return 1
    nds_import_file "${tools_dir}/wizard/load.sh" || return 1
    nds_git_wizard_load "${tools_dir}/wizard" || return 1
    nds_import_file "${tools_dir}/auth.sh" || return 1
    NDS_GIT_TOOLS_LOADED=true
    return 0
}
