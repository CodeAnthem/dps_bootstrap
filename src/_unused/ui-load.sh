#!/usr/bin/env bash
# Shim — UI primitives loaded by core/bootstrap.sh
nds_ui_load() {
    local lib_dir="${1:?lib dir}"
    nds_import_file "${lib_dir}/ui/terminal.sh" || return 1
    nds_import_file "${lib_dir}/ui/output.sh" || return 1
    nds_import_file "${lib_dir}/ui/stepAnimation.sh" || return 1
    nds_import_file "${lib_dir}/ui/prompts.sh" || return 1
    nds_ui_init
    return 0
}
