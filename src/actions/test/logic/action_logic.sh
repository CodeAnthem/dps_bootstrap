#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test action (logic) — full selftest suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-07
# Description:   Run the same self-tests CI runs (read-only — no system changes)
# ==================================================================================================

action_config() {
    nds_cfg_preset_disable disk
    nds_cfg_preset_disable quick
    nds_cfg_preset_disable region
    nds_cfg_preset_disable network
    nds_cfg_preset_disable boot
    nds_cfg_preset_disable installFlake
}

action_setup() {
    console "Running full NDS self-tests (same as CI / bash src/tests/run.sh)."
    bash "${SCRIPT_DIR}/tests/run.sh" || exit 1
}
