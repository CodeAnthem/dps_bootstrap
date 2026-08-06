#!/usr/bin/env bash
# ==================================================================================================
# NDS - App lifecycle (staged loader)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-06
# Description:   Staged backbone load; features via nds_import_tree (no nested load.sh)
# ==================================================================================================

# Description: Load core primitives + tools capability helpers.
nds_lifecycle_load_core() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_dir "${script_dir}/core" false || return 1
    nds_import_tree "${script_dir}/tools" || return 1
    return 0
}

# Description: Load shared UI (terminal → logger → section → prompts → animation).
nds_lifecycle_load_ui() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_file "${script_dir}/ui/terminal.sh" || return 1
    nds_import_file "${script_dir}/ui/logger.sh" || return 1
    nds_import_file "${script_dir}/ui/section.sh" || return 1
    nds_import_file "${script_dir}/ui/prompts.sh" || return 1
    nds_import_file "${script_dir}/ui/stepAnimation.sh" || return 1
    nds_ui_init
    return 0
}

# Description: Load action runtime pieces. settingsManager is deferred to action runtime.
nds_lifecycle_load_actions() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_file "${script_dir}/app/state.sh" || return 1
    nds_import_file "${script_dir}/app/action-store.sh" || return 1
    nds_import_file "${script_dir}/app/action-preview.sh" || return 1
    nds_import_file "${script_dir}/app/action-handler.sh" || return 1
    nds_import_file "${script_dir}/app/cli.sh" || return 1
    nds_import_file "${script_dir}/app/exit.sh" || return 1
    nds_import_file "${script_dir}/app/menus/install-confirm.sh" || return 1
    nds_import_file "${script_dir}/app/menus/remote-confirm.sh" || return 1
    nds_import_file "${script_dir}/app/bootstrap.sh" || return 1
    return 0
}
