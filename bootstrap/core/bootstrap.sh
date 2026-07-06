#!/usr/bin/env bash
# ==================================================================================================
# NDS - Core bootstrap (module load order)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Load core runtime, UI primitives, settingsManager, tools, install stack
# ==================================================================================================

nds_core_load_all() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"
    local lib_dir="${script_dir}/lib"

    nds_import_dir "${lib_dir}/core" false || return 1

    nds_import_file "${script_dir}/validators/load.sh" || return 1
    nds_import_file "${script_dir}/settingsManager/load.sh" || return 1
    nds_settings_manager_load "${script_dir}/settingsManager" "${script_dir}/validators" || return 1

    nds_import_file "${lib_dir}/ui/terminal.sh" || return 1
    nds_import_file "${lib_dir}/ui/output.sh" || return 1
    nds_import_file "${lib_dir}/ui/stepAnimation.sh" || return 1
    nds_import_file "${lib_dir}/ui/prompts.sh" || return 1
    nds_ui_init

    nds_import_file "${script_dir}/core/menus/menu.install-confirm.sh" || return 1
    nds_import_file "${script_dir}/core/menus/menu.remote-confirm.sh" || return 1
    nds_import_file "${script_dir}/core/actions.sh" || return 1

    nds_import_file "${lib_dir}/load.sh" || return 1
    nds_configurator_init || return 1
    nds_installation_init || return 1
    return 0
}
