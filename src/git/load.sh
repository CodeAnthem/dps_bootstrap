#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-05
# Description:   Load standalone git helpers, then framework git + UI
# ==================================================================================================

nds_git_tools_load() {
    [[ "${NDS_GIT_TOOLS_LOADED:-false}" == "true" ]] && return 0
    local tools_dir="${1:?tools dir}"

    nds_import_file "${SCRIPT_DIR}/git/lib/load.sh" || return 1
    nds_standalone_git_load || return 1
    nds_import_file "${tools_dir}/lib/ssh.sh" || return 1
    nds_import_file "${tools_dir}/logic/load.sh" || return 1
    nds_git_logic_load "${tools_dir}/logic" || return 1
    nds_import_file "${tools_dir}/ui/load.sh" || return 1
    nds_git_wizard_load "${tools_dir}/ui" || return 1
    NDS_GIT_TOOLS_LOADED=true
    return 0
}
