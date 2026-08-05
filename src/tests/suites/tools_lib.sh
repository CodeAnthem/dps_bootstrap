#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared tools/lib selfchecks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

suite_tools_lib() {
    if declare -f nds_pkg_cmd &>/dev/null \
        && declare -f nds_qr_print &>/dev/null \
        && declare -f nds_gh_ensure &>/dev/null \
        && declare -f nds_age_keygen &>/dev/null \
        && declare -f nds_facter_write &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ tools/lib: pkg/qr/gh/age/facter loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ tools/lib: helpers missing"
    fi

    if declare -f nds_pkg_cmd &>/dev/null; then
        local -a cmd=()
        if command -v bash &>/dev/null && nds_pkg_cmd cmd bash bash \
            && [[ "${cmd[0]}" == "bash" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ pkg_cmd: resolves PATH binary"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ pkg_cmd: PATH resolve"
        fi
    fi

    if declare -f nds_git_qr_show_payload &>/dev/null \
        || declare -f nds_git_qr_show_manual_bundle &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ legacy git QR helpers still present"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git QR helpers removed (use nds_qr_*)"
    fi
}
