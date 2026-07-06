#!/usr/bin/env bash
# ==================================================================================================
# NDS - nixWriter load order
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

nds_nixwriter_load() {
    local root="${1:?nixWriter root}"
    nds_import_file "${root}/builder.sh" || return 1
    nds_import_file "${root}/escape.sh" || return 1
    nds_import_dir "${root}/blocks" false || return 1
    nds_import_file "${root}/classic.sh" || return 1
    return 0
}
