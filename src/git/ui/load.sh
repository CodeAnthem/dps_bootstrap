#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

nds_git_wizard_load() {
    local wizard_dir="${1:?wizard dir}"
    nds_import_file "${wizard_dir}/screens.sh" || return 1
    nds_import_file "${wizard_dir}/import_menu.sh" || return 1
    nds_import_file "${wizard_dir}/manual_menu.sh" || return 1
    nds_import_file "${wizard_dir}/gh_menu.sh" || return 1
    nds_import_file "${wizard_dir}/new_key_menu.sh" || return 1
    nds_import_file "${wizard_dir}/flow.sh" || return 1
    return 0
}
