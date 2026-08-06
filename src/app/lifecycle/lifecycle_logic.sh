#!/usr/bin/env bash
# ==================================================================================================
# NDS - App lifecycle (staged loader)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-06
# Description:   Staged backbone load; features via nds_import_tree (no nested load.sh)
# ==================================================================================================

# Description: Load app/core primitives (import.sh already sourced) + tools.
nds_lifecycle_load_core() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"
    local core_dir="${script_dir}/app/core"

    nds_import_file "${core_dir}/mode.sh" || return 1
    nds_import_file "${core_dir}/platform.sh" || return 1
    nds_import_file "${core_dir}/runtime.sh" || return 1
    nds_import_file "${core_dir}/strings.sh" || return 1
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

# Description: Load action runtime + confirm menus. settingsManager deferred.
nds_lifecycle_load_actions() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_tree "${script_dir}/app/runtime" || return 1
    nds_import_tree "${script_dir}/app/menus" || return 1
    return 0
}
