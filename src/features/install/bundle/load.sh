#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install bundle loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

nds_install_bundle_load() {
    local bundle_dir="${1:?bundle dir}"
    nds_import_file "${bundle_dir}/paths.sh" || return 1
    nds_import_file "${bundle_dir}/quickstart.sh" || return 1
    nds_import_file "${bundle_dir}/hints.sh" || return 1
    nds_import_file "${bundle_dir}/create.sh" || return 1
    nds_import_file "${bundle_dir}/finish.sh" || return 1
    return 0
}
