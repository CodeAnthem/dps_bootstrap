#!/usr/bin/env bash
# ==================================================================================================
# NDS - App lifecycle (staged loader)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-05
# Description:   Explicit staged load functions; settingsManager deferred to action runtime
# ==================================================================================================

# Description: Load primitive shared core (import, runtime, platform, strings)
# and sourcable tools/lib helpers (pkg, qr, age, facter). No UI, no settings.
nds_lifecycle_load_core() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_dir "${script_dir}/core" false || return 1
    nds_import_file "${script_dir}/tools/lib/load.sh" || return 1
    nds_tools_lib_load "${script_dir}/tools/lib" || return 1
    return 0
}

# Description: Load shared UI (terminal, output, prompts, stepAnimation, skip registry).
nds_lifecycle_load_ui() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_file "${script_dir}/ui/terminal.sh" || return 1
    nds_import_file "${script_dir}/ui/output.sh" || return 1
    nds_import_file "${script_dir}/ui/stepAnimation.sh" || return 1
    nds_import_file "${script_dir}/ui/skip.sh" || return 1
    nds_import_file "${script_dir}/ui/prompts.sh" || return 1
    nds_ui_init
    return 0
}

# Description: Load standalone validators, action store, action handler, confirm menus,
# and framework bootstrap helpers. settingsManager itself is NOT loaded here.
nds_lifecycle_load_actions() {
    local script_dir="${1:-${SCRIPT_DIR:-}}"

    nds_import_file "${script_dir}/validators/load.sh" || return 1
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
