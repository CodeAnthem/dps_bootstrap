#!/usr/bin/env bash
# ==================================================================================================
# NDS - Partition tools compatibility shims
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-06-28
# Description:   Bridge legacy partitionTools APIs to current configurator
# ==================================================================================================

nds_cfg_get_env() {
    nds_configurator_config_get_env "$@"
}

run_step() {
    local title="$1"
    shift
    step_start "$title"
    if "$@"; then
        step_complete "$title"
        return 0
    fi
    step_fail "$title"
    return 1
}

pass() { success "$1"; }
