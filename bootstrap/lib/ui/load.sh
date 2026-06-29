#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI package loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Load terminal, output, step animation, prompts, and action UI modules
# ==================================================================================================

# Description: Load all UI modules and initialize terminal mode.
# Arguments:
# - lib_dir: <String> Path to bootstrap/lib
# Returns:
# - 0 on success
nds_ui_load() {
    local lib_dir="${1:?lib dir required}"

    nds_import_file "${lib_dir}/ui/terminal.sh" || return 1
    nds_import_file "${lib_dir}/ui/output.sh" || return 1
    nds_import_file "${lib_dir}/ui/stepAnimation.sh" || return 1
    nds_import_file "${lib_dir}/ui/prompts.sh" || return 1
    nds_import_file "${lib_dir}/ui/actions.sh" || return 1
    nds_ui_init
    return 0
}
