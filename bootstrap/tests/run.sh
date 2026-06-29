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

nds_run_self_tests() {
    TEST_PASSED=0
    TEST_FAILED=0

    section_title "NDS self-tests"

    run_named_suite "configurator" suite_configurator
    run_named_suite "inputs" suite_inputs
    run_named_suite "classicConfig" suite_classic_config

    print_test_summary
}

nds_run_self_tests
