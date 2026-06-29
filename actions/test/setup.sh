#!/usr/bin/env bash
# ==================================================================================================
# Metadata:      Test Action
# Description:   Run NDS self-tests (configurator, inputs, classicConfig) — no system changes
# ==================================================================================================

action_config() {
    nds_configurator_preset_disable disk
    nds_configurator_preset_disable quick
    nds_configurator_preset_disable region
    nds_configurator_preset_disable network
    nds_configurator_preset_disable boot
    nds_configurator_preset_disable security
    nds_configurator_preset_disable installFlake
}

action_setup() {
    console "Running NDS self-tests (read-only)."
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/tests/framework.sh"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/tests/suites/configurator.sh"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/tests/suites/inputs.sh"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/tests/suites/classicConfig.sh"

    TEST_PASSED=0
    TEST_FAILED=0
    section_title "NDS self-tests"

    run_named_suite "configurator" suite_configurator
    run_named_suite "inputs" suite_inputs
    run_named_suite "classicConfig" suite_classic_config

    print_test_summary || exit 1
}
