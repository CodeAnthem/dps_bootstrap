#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle feature loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Core bundle: register hooks + create + finish UX
# ==================================================================================================

nds_bundle_load() {
    local bundle_dir="${1:?bundle dir}"
    [[ "${NDS_BUNDLE_LOADED:-false}" == "true" ]] && return 0

    nds_import_file "${bundle_dir}/logic/register_logic.sh" || return 1
    nds_import_file "${bundle_dir}/logic/paths_logic.sh" || return 1
    nds_import_file "${bundle_dir}/logic/quickstart_logic.sh" || return 1
    nds_import_file "${bundle_dir}/logic/create_logic.sh" || return 1
    nds_import_file "${bundle_dir}/ui/hints_display.sh" || return 1
    nds_import_file "${bundle_dir}/ui/finish_prompts.sh" || return 1

    NDS_BUNDLE_LOADED=true
    return 0
}

# Compat for callers that still expect the install-scoped name.
nds_install_bundle_load() {
    nds_bundle_load "$@"
}
