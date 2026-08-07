#!/usr/bin/env bash
# ==================================================================================================
# NDS - Structure / layout selfchecks (CI-safe)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-07
# Description:   Post-refactor layout invariants — no TTY, no disk wipe
# ==================================================================================================

suite_structure() {
    local f missing=0

    if [[ -d "${SCRIPT_DIR}/git/github" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git/github still present"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no src/git/github (GH lives in tools/)"
    fi

    if [[ -d "${SCRIPT_DIR}/app/mode" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover empty app/mode/"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no leftover app/mode/"
    fi

    if find "${SCRIPT_DIR}" -type f -name 'load.sh' ! -path '*/tests/*' 2>/dev/null | grep -q .; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nested load.sh still present under src/"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nested load.sh under src/"
    fi

    if declare -f nds_git_gh_cmd &>/dev/null || declare -f nds_git_gh_ensure &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_gh_* aliases still defined"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nds_git_gh_* aliases"
    fi

    if declare -f nds_install_bundle_create &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_bundle_* alias still defined"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nds_install_bundle_* aliases"
    fi

    for f in \
        "${SCRIPT_DIR}/git/logic" \
        "${SCRIPT_DIR}/git/ui" \
        "${SCRIPT_DIR}/install/logic" \
        "${SCRIPT_DIR}/install/ui" \
        "${SCRIPT_DIR}/bundle/logic" \
        "${SCRIPT_DIR}/bundle/ui" \
        "${SCRIPT_DIR}/app/runtime" \
        "${SCRIPT_DIR}/app/ui" \
        "${SCRIPT_DIR}/actions/uiSmoke/logic" \
        "${SCRIPT_DIR}/actions/uiSmoke/ui" \
        "${SCRIPT_DIR}/actions/test/logic" \
        "${SCRIPT_DIR}/actions/test/ui"
    do
        if [[ ! -d "$f" ]]; then
            missing=1
            console "  ✗ missing layout dir: ${f#"$SCRIPT_DIR"/}"
        fi
    done
    if [[ "$missing" -eq 0 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ feature layout dirs present (logic/ui + debug actions)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
    fi

    if declare -f nds_gh_ensure &>/dev/null \
        && declare -f nds_bundle_create &>/dev/null \
        && declare -f nds_import_tree &>/dev/null \
        && declare -f nds_cfg_print_backup &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key public APIs present (gh/bundle/import/cfg UI)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ missing key public APIs"
    fi

    # Soft: UI call sites must not live in feature logic (comments OK).
    if command -v rg &>/dev/null; then
        local hits
        hits=$(rg -n '^\s*(nds_ui_|nds_ask_user)' \
            "${SCRIPT_DIR}/git/logic" \
            "${SCRIPT_DIR}/install/logic" \
            "${SCRIPT_DIR}/bundle/logic" \
            "${SCRIPT_DIR}/settingsManager/logic" \
            "${SCRIPT_DIR}/app/runtime" \
            --glob '*.sh' 2>/dev/null || true)
        if [[ -n "$hits" ]]; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ UI calls still in logic/runtime:"
            while IFS= read -r line; do
                console "      $line"
            done <<< "$hits"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ no prompt UI calls in feature logic/runtime"
        fi
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ (skip logic/UI grep — rg not installed)"
    fi
}
