#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test runner
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2026-06-29
# Description:   Run all NDS self-test suites (read-only — no system changes)
# ==================================================================================================

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_ROOT
SCRIPT_DIR="$(cd "${TEST_ROOT}/.." && pwd)"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/core/import.sh"
nds_bootstrap_load_libs "$SCRIPT_DIR"

# shellcheck disable=SC1091
source "${TEST_ROOT}/framework.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/configurator.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/inputs.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/classicConfig.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/git.sh"

# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/presets.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/validators.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/settingsManager.sh"
# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/nixWriter.sh"

# shellcheck disable=SC1091
source "${TEST_ROOT}/suites/skip.sh"

nds_run_self_tests() {
    TEST_PASSED=0
    TEST_FAILED=0

    section_title "NDS self-tests"

    run_named_suite "settingsManager" suite_settings_manager
    run_named_suite "skip" suite_skip
    run_named_suite "configurator" suite_configurator
    run_named_suite "presets" suite_presets
    run_named_suite "validators" suite_validators
    run_named_suite "nixWriter" suite_nixwriter
    run_named_suite "git" suite_git
    run_named_suite "inputs" suite_inputs
    run_named_suite "classicConfig" suite_classic_config

    print_test_summary
}

nds_run_self_tests
