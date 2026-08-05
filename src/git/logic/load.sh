#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git framework logic loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-08-05
# ==================================================================================================

nds_git_logic_load() {
    [[ "${NDS_GIT_LOGIC_LOADED:-false}" == "true" ]] && return 0
    local logic_dir="${1:?logic dir}"

    nds_import_file "${logic_dir}/prefetch_logic.sh" || return 1
    nds_import_file "${logic_dir}/probe_logic.sh" || return 1
    nds_import_file "${logic_dir}/closure_logic.sh" || return 1
    nds_import_file "${logic_dir}/key_logic.sh" || return 1
    nds_import_file "${logic_dir}/keys_logic.sh" || return 1
    nds_import_file "${logic_dir}/discover_logic.sh" || return 1
    nds_import_file "${logic_dir}/access_state_logic.sh" || return 1
    nds_import_file "${logic_dir}/auth-flow.sh" || return 1
    nds_import_file "${logic_dir}/git_access_logic.sh" || return 1
    nds_import_file "${logic_dir}/auth_logic.sh" || return 1
    NDS_GIT_LOGIC_LOADED=true
    return 0
}
