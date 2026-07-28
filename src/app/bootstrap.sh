#!/usr/bin/env bash
# ==================================================================================================
# NDS - Core bootstrap (staged framework load)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Preload basic runtime, then let the selected action extend settingsManager
#                before loading the heavier framework modules.
# ==================================================================================================

nds_core_preload_basic() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_dir "${script_dir}/shared/core" false || return 1

    nds_import_file "${script_dir}/standalone/validators/load.sh" || return 1
    nds_import_file "${script_dir}/framework/settings-manager/load.sh" || return 1
    nds_settings_manager_load \
        "${script_dir}/framework/settings-manager" \
        "${script_dir}/standalone/validators" || return 1

    nds_import_file "${script_dir}/shared/ui/terminal.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/output.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/stepAnimation.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/prompts.sh" || return 1
    nds_ui_init

    nds_import_file "${script_dir}/app/menus/menu.install-confirm.sh" || return 1
    nds_import_file "${script_dir}/app/menus/menu.remote-confirm.sh" || return 1
    nds_import_file "${script_dir}/app/actions.sh" || return 1
    nds_import_file "${script_dir}/framework/bootstrap/load.sh" || return 1
    return 0
}

nds_core_load_all() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"
    nds_core_preload_basic "$script_dir"
}
