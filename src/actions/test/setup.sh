#!/usr/bin/env bash
# ==================================================================================================
# Metadata:      Test Action
# Description:   Run NDS self-tests (cfg, inputs, classicConfig) — no system changes
# ==================================================================================================

action_config() {
    nds_cfg_preset_disable disk
    nds_cfg_preset_disable quick
    nds_cfg_preset_disable region
    nds_cfg_preset_disable network
    nds_cfg_preset_disable boot
    nds_cfg_preset_disable installFlake
}

action_preview() {
    nds_ui_h "NDS self-tests (read-only)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "nothing — no install settings required"
    nds_ui_b ""
    nds_ui_b "NDS will:"
    nds_action_items "run cfg tests, run inputs tests, run classicConfig tests"
    nds_ui_b ""
}

action_setup() {
    console "Running NDS self-tests (read-only)."
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/tests/framework.sh"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/settingsManager/tests/cfg_suite_test.sh"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/settingsManager/tests/inputs_suite_test.sh"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/install/tests/classic_config_suite_test.sh"

    TEST_PASSED=0
    TEST_FAILED=0
    nds_ui_section_title "NDS self-tests"

    run_named_suite "cfg" suite_cfg
    run_named_suite "inputs" suite_inputs
    run_named_suite "classicConfig" suite_classic_config

    print_test_summary || exit 1
}
