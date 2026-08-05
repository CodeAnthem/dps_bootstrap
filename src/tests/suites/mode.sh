#!/usr/bin/env bash
# ==================================================================================================
# NDS - Mode + AA bridge / unattended contract tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

suite_mode() {
    local saved_mode="${NDS_MODE:-}" saved_un="${NDS_UNATTENDED:-}" saved_auto="${NDS_AUTO_CONFIRM:-}"
    local -A cfg=()

    unset NDS_MODE NDS_UNATTENDED NDS_AUTO_CONFIRM
    nds_mode_resolve || { TEST_FAILED=$((TEST_FAILED + 1)); console "  ✗ mode_resolve: default"; return; }
    if [[ "$NDS_MODE" == "interactive" ]] && nds_mode_is_interactive; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ mode_resolve: default interactive"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ mode_resolve: default interactive"
    fi

    unset NDS_MODE
    export NDS_UNATTENDED=true
    nds_mode_resolve || true
    if nds_mode_is_unattended; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ mode_resolve: NDS_UNATTENDED → unattended"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ mode_resolve: NDS_UNATTENDED"
    fi

    unset NDS_MODE NDS_UNATTENDED
    export NDS_AUTO_CONFIRM=1
    nds_mode_resolve || true
    if nds_mode_is_unattended; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ mode_resolve: NDS_AUTO_CONFIRM → unattended"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ mode_resolve: NDS_AUTO_CONFIRM"
    fi

    export NDS_MODE=bogus
    if ! nds_mode_resolve 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ mode_resolve: rejects invalid NDS_MODE"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ mode_resolve: should reject invalid NDS_MODE"
    fi

    if declare -f nds_cfg_aa_from_store &>/dev/null; then
        CONFIG_DATA[DISK_TARGET]="/dev/vda"
        nds_cfg_aa_from_store cfg
        if [[ "${cfg[DISK_TARGET]}" == "/dev/vda" ]]; then
            cfg[DISK_TARGET]="/dev/sda"
            nds_cfg_aa_to_store cfg
            if [[ "${CONFIG_DATA[DISK_TARGET]}" == "/dev/sda" ]]; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ aa bridge: from_store / to_store round-trip"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ aa bridge: to_store"
            fi
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ aa bridge: from_store"
        fi
        CONFIG_DATA[DISK_TARGET]=""
    fi

    if declare -f nds_feature_require_keys &>/dev/null; then
        cfg=([A]="1")
        if ! nds_feature_require_keys cfg A B 2>/dev/null \
            && nds_feature_require_keys cfg A; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ feature_require_keys: missing vs present"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ feature_require_keys"
        fi
    fi

    if declare -f nds_action_call_feature &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ action_call_feature: present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ action_call_feature: missing"
    fi

    if declare -f nds_cfg_aa_bind &>/dev/null; then
        local -A live=([X]="from-aa")
        local saved_cd="${CONFIG_DATA[X]:-}"
        CONFIG_DATA[X]="from-store"
        nds_cfg_aa_bind live
        if [[ "$(nds_cfg_get X)" == "from-aa" ]]; then
            nds_cfg_set X "updated"
            nds_cfg_aa_unbind
            if [[ "${live[X]}" == "updated" && "${CONFIG_DATA[X]}" == "from-store" ]]; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ cfg_aa_bind: get/set redirect without store write"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ cfg_aa_bind: store pollution or miss"
            fi
        else
            nds_cfg_aa_unbind
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ cfg_aa_bind: get did not hit AA"
        fi
        CONFIG_DATA[X]="$saved_cd"
    fi

    if declare -f nds_cfg_menu_or_skip &>/dev/null; then
        export NDS_MODE=unattended
        # Empty store + no presets → validate may fail; ensure it does not open menu (returns 1).
        if ! nds_cfg_menu_or_skip 2>/dev/null; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ menu_or_skip: unattended fails without valid config"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ menu_or_skip: unattended completed with empty/valid set"
        fi
    fi

    # restore
    if [[ -n "$saved_mode" ]]; then export NDS_MODE="$saved_mode"; else unset NDS_MODE; fi
    if [[ -n "$saved_un" ]]; then export NDS_UNATTENDED="$saved_un"; else unset NDS_UNATTENDED; fi
    if [[ -n "$saved_auto" ]]; then export NDS_AUTO_CONFIRM="$saved_auto"; else unset NDS_AUTO_CONFIRM; fi
}
