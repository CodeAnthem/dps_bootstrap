#!/usr/bin/env bash
# ==================================================================================================
# NDS - System variables loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Load NDS_* environment bridge (depends on settings store)
# ==================================================================================================

nds_system_vars_load() {
    local root="${1:?system-vars dir}"
    nds_import_file "${root}/env.sh" || return 1
    return 0
}
