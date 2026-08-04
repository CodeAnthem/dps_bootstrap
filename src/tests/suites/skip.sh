#!/usr/bin/env bash
# ==================================================================================================
# NDS - Menu skip env tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-29
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

    nds_actions_discover "${SCRIPT_DIR}/actions" || return 1
    export NDS_ACTION=installFlake
    NDS_CURRENT_ACTION=""
    if nds_actions_select_from_env && [[ "$NDS_CURRENT_ACTION" == "installFlake" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_actions_select_from_env: installFlake"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_actions_select_from_env: installFlake"
    fi

    export NDS_ACTION=not_a_real_action
    NDS_CURRENT_ACTION=""
    if ! nds_actions_select_from_env 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_actions_select_from_env: rejects invalid action"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_actions_select_from_env: rejects invalid action"
    fi
    unset NDS_ACTION NDS_CURRENT_ACTION

    if declare -f nds_settings_catalog_init &>/dev/null \
        && declare -f nds_framework_prepare_action_runtime &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ staged load: catalog + prepare helpers present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ staged load: catalog/prepare helpers missing"
    fi

    if declare -f nds_git_cfg_owner_slug &>/dev/null \
        && declare -f nds_git_clone_with_key &>/dev/null \
        && declare -f nds_install_ctx_get &>/dev/null \
        && declare -f nds_cfg_apply_env_all &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ module boundaries: validators/settings helpers loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ module boundaries: expected helpers missing"
    fi

    # Fresh process mimics main.sh: lifecycle only — no pre-sourced git/lib|install/lib.
    # Catches loaders that call nds_standalone_*_load without importing load.sh.
    local prepare_out=""
    if prepare_out=$(
        env SCRIPT_DIR="$SCRIPT_DIR" bash -euo pipefail -c '
            source "${SCRIPT_DIR}/core/import.sh"
            nds_bootstrap_load_libs "$SCRIPT_DIR" || exit 1
            nds_framework_prepare_action_runtime || exit 1
            declare -f nds_standalone_git_load >/dev/null
            declare -f nds_standalone_install_load >/dev/null
            declare -f nds_nixos_install >/dev/null
        ' 2>&1
    ); then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ prepare_action_runtime: loads standalone deps without pre-source"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ prepare_action_runtime: loads standalone deps without pre-source"
        console "    ${prepare_out}"
    fi
}
