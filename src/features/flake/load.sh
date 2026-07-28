#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake tools loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Load flake helpers (prepare, scaffold, probe paths)
# ==================================================================================================

nds_flake_tools_load() {
    local tools_dir="${1:?flake tools dir}"
    nds_import_file "${tools_dir}/helpers.sh" || return 1
    return 0
}
