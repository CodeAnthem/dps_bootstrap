#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared sourcable tools (PATH / nixpkgs helpers)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Capability libs for any feature — not target CLIs in tools/*.sh
# ==================================================================================================

nds_tools_lib_load() {
    local lib_dir="${1:?tools lib dir}"
    [[ "${NDS_TOOLS_LIB_LOADED:-false}" == "true" ]] && return 0
    nds_import_file "${lib_dir}/pkg.sh" || return 1
    nds_import_file "${lib_dir}/qr.sh" || return 1
    nds_import_file "${lib_dir}/age.sh" || return 1
    nds_import_file "${lib_dir}/facter.sh" || return 1
    NDS_TOOLS_LIB_LOADED=true
    return 0
}
