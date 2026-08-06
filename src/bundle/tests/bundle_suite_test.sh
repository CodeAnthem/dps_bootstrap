#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle core feature selfchecks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

suite_bundle() {
    if declare -f nds_bundle_register_file &>/dev/null \
        && declare -f nds_bundle_create &>/dev/null \
        && declare -f nds_bundle_path &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle: register/create/path API loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle: core API missing"
    fi

    if declare -f nds_install_bundle_create &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle: install compat aliases present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle: install compat aliases missing"
    fi

    if nds_import_file "${SCRIPT_DIR}/bundle/tests/register_test.sh" 2>/dev/null \
        && nds_test_bundle_register_api; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle: register hooks materialize files"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle: register hooks materialize"
    fi
}
