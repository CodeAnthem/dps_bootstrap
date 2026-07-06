#!/usr/bin/env bash
# ==================================================================================================
# NDS - Menu skip env tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

suite_skip() {
    unset NDS_AUTO_CONFIRM NDS_INSTALL_CONFIRM_SKIP

    if nds_env_is_true true && nds_env_is_true 1; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_env_is_true: true and 1"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_env_is_true: true and 1"
    fi

    if ! nds_env_is_true false && ! nds_env_is_true ""; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_env_is_true: false and empty"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_env_is_true: false and empty"
    fi

    export NDS_INSTALL_CONFIRM_SKIP=true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_skip_menu: specific flag"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_skip_menu: specific flag"
    fi
    unset NDS_INSTALL_CONFIRM_SKIP

    export NDS_AUTO_CONFIRM=true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_skip_menu: NDS_AUTO_CONFIRM umbrella"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_skip_menu: NDS_AUTO_CONFIRM umbrella"
    fi
    unset NDS_AUTO_CONFIRM

    nds_actions_discover "${SCRIPT_DIR}/../actions" || return 1
    export NDS_ACTION=installFlake
    current_action=""
    if nds_actions_select_from_env && [[ "$current_action" == "installFlake" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_actions_select_from_env: installFlake"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_actions_select_from_env: installFlake"
    fi

    export NDS_ACTION=not_a_real_action
    current_action=""
    if ! nds_actions_select_from_env 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_actions_select_from_env: rejects invalid action"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_actions_select_from_env: rejects invalid action"
    fi
    unset NDS_ACTION current_action
}
