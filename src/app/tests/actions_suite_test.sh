#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action discovery selfcheck
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-07
# ==================================================================================================

suite_actions() {
    local -a names=()
    local n

    NDS_ACTION_NAMES=()
    unset NDS_ACTION_DATA
    declare -gA NDS_ACTION_DATA=()

    if ! nds_actions_discover "${SCRIPT_DIR}/actions"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_actions_discover failed"
        return 0
    fi

    for n in "${NDS_ACTION_NAMES[@]}"; do
        names+=("$n")
    done

    local have_classic=0 have_flake=0 have_remote=0 have_test=0 have_smoke=0
    for n in "${names[@]}"; do
        [[ "$n" == "classicInstall" ]] && have_classic=1
        [[ "$n" == "installFlake" ]] && have_flake=1
        [[ "$n" == "remoteAction" ]] && have_remote=1
        [[ "$n" == "test" ]] && have_test=1
        [[ "$n" == "uiSmoke" ]] && have_smoke=1
    done

    if [[ "$have_classic" -eq 1 && "$have_flake" -eq 1 && "$have_remote" -eq 1 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover: classicInstall / installFlake / remoteAction"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover: missing production actions (${names[*]})"
    fi

    if [[ "$have_test" -eq 0 && "$have_smoke" -eq 0 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover: test/uiSmoke hidden without NDS_TEST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover: debug actions visible without NDS_TEST"
    fi

    NDS_TEST=true
    NDS_ACTION_NAMES=()
    unset NDS_ACTION_DATA
    declare -gA NDS_ACTION_DATA=()
    nds_actions_discover "${SCRIPT_DIR}/actions" || true
    have_test=0 have_smoke=0
    for n in "${NDS_ACTION_NAMES[@]}"; do
        [[ "$n" == "test" ]] && have_test=1
        [[ "$n" == "uiSmoke" ]] && have_smoke=1
    done
    unset NDS_TEST

    if [[ "$have_test" -eq 1 && "$have_smoke" -eq 1 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover: test + uiSmoke when NDS_TEST=true"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover: NDS_TEST did not surface test/uiSmoke"
    fi
}
