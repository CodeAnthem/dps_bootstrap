#!/usr/bin/env bash
# ==================================================================================================
# Metadata:      Test Action
# Description:   Run test suite for inputs and configuration system
# ==================================================================================================

# ----------------------------------------------------------------------------------
# SETUP FUNCTION (Required by action system)
# ----------------------------------------------------------------------------------
setup() {
    # Source and run the main test runner
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/tests/run.sh"
    run_all_tests
}
