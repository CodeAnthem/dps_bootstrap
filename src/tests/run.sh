#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test runner
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2026-08-06
# Description:   Cross-feature suites (feature unit tests live under each feature)
# ==================================================================================================

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_ROOT
SCRIPT_DIR="$(cd "${TEST_ROOT}/.." && pwd)"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/core/import.sh"
nds_bootstrap_load_libs "$SCRIPT_DIR"
nds_cfg_init
nds_framework_load_remaining

source "${TEST_ROOT}/framework.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/cfg.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/inputs.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/classicConfig.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/standalone.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/git.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/mode.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/tools_lib.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/bundle.sh"

# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/presets.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/../settingsManager/tests/validators_test.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/settingsManager.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/nixWriter.sh"

# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/skip.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/install.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/facter.sh"

nds_run_self_tests() {
    TEST_PASSED=0
    TEST_FAILED=0

    nds_ui_section_title "NDS self-tests"

    run_named_suite "settingsManager" suite_settings_manager
    run_named_suite "skip" suite_skip
    run_named_suite "cfg" suite_cfg
    run_named_suite "presets" suite_presets
    run_named_suite "validators" suite_validators
    run_named_suite "nixWriter" suite_nixwriter
    run_named_suite "standalone" suite_standalone
    run_named_suite "git" suite_git
    run_named_suite "mode" suite_mode
    run_named_suite "tools_lib" suite_tools_lib
    run_named_suite "bundle" suite_bundle
    run_named_suite "inputs" suite_inputs
    run_named_suite "classicConfig" suite_classic_config
    run_named_suite "install" suite_install
    run_named_suite "facter" suite_facter

    print_test_summary
}

nds_run_self_tests
