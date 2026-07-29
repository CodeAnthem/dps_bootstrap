#!/usr/bin/env bash
# ==================================================================================================
# NDS - App lifecycle (staged loader)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Explicit staged load functions; settingsManager deferred to action runtime
# ==================================================================================================

# Description: Load primitive shared core (import, runtime, platform, strings).
# No UI, no settings, no actions.
nds_lifecycle_load_core() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_dir "${script_dir}/shared/core" false || return 1
    return 0
}

# Description: Load shared UI (terminal, output, prompts, stepAnimation, skip registry).
nds_lifecycle_load_ui() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_file "${script_dir}/shared/ui/terminal.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/output.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/stepAnimation.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/skip.sh" || return 1
    nds_import_file "${script_dir}/shared/ui/prompts.sh" || return 1
    nds_ui_init
    return 0
}

# Description: Load standalone validators, action store, action handler, confirm menus,
# and framework bootstrap helpers. settingsManager itself is NOT loaded here.
nds_lifecycle_load_actions() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_file "${script_dir}/standalone/validators/load.sh" || return 1
    nds_import_file "${script_dir}/app/action-store.sh" || return 1
    nds_import_file "${script_dir}/app/action-preview.sh" || return 1
    nds_import_file "${script_dir}/app/action-handler.sh" || return 1
    nds_import_file "${script_dir}/app/cli.sh" || return 1
    nds_import_file "${script_dir}/app/exit.sh" || return 1
    nds_import_file "${script_dir}/app/menus/install-confirm.sh" || return 1
    nds_import_file "${script_dir}/app/menus/remote-confirm.sh" || return 1
    nds_import_file "${script_dir}/framework/bootstrap/load.sh" || return 1
    return 0
}
