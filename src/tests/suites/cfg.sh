#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings cfg smoke tests (read-only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# # Date:          Created: 2026-06-29 | Modified: 2026-08-04
# ==================================================================================================

suite_cfg() {
    if [[ ${#PRESET_REGISTRY[@]} -eq 0 ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ no presets registered"
        return 0
    fi

    TEST_PASSED=$((TEST_PASSED + 1))
    console "  ✓ presets registered: ${#PRESET_REGISTRY[@]}"

    local required_presets=(disk encryption region network boot access quick)
    local preset
    for preset in "${required_presets[@]}"; do
        if [[ "${PRESET_REGISTRY[$preset]:-}" == "enabled" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ preset enabled: $preset"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ preset missing or disabled: $preset"
        fi
    done

    CONFIG_DATA[NETWORK_HOSTNAME]=""
    if network_validate &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ network_validate should reject empty hostname"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ network_validate rejects empty hostname"
    fi

    CONFIG_DATA[NETWORK_HOSTNAME]="myhost"
    if network_validate &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ network_validate accepts valid hostname"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ network_validate should accept valid hostname"
    fi

    nds_cfg_snapshot_defaults
    CONFIG_DATA[DISK_TARGET]="/dev/testdisk"
    CONFIG_DATA[REGION_TIMEZONE]="Europe/Test"
    local grouped
    grouped="$(nds_cfg_export_grouped)"
    if [[ "$(grep -c '^export ' <<<"$grouped")" -ge 3 ]] \
       && grep -q 'NDS_REGION_TIMEZONE="Europe/Test"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: one export per line, portable value present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export malformed"
    fi
    if grep -qE '^# This machine only' <<<"$grouped" \
       && grep -q 'NDS_DISK_TARGET="/dev/testdisk"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: hardware split holds DISK_TARGET"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: hardware split missing DISK_TARGET"
    fi
    if grep -qE '^# Menu control' <<<"$grouped" \
       && grep -q 'NDS_SKIP_MENU="false"' <<<"$grouped" \
       && grep -q 'NDS_AUTO_CONFIRM="false"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: menu skip flags default false"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: menu skip flags missing"
    fi

    if ! grep -Pz '# Configuration — portable[^\n]*\n\nexport ' <<<"$grouped" \
       && ! grep -Pz '# This machine only[^\n]*\n\nexport ' <<<"$grouped" \
       && ! grep -Pz '# Menu control[^\n]*\n\nexport ' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: no blank line between section comment and exports"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: unexpected blank line after section comment"
    fi

    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    CONFIG_DATA[PLATFORM_RUN_ON_VM]="true"
    CONFIG_DATA[PLATFORM_VM_TYPE]="vmware"
    grouped="$(nds_cfg_export_grouped)"
    if awk '/^# This machine only/,/^# Menu control/' <<<"$grouped" | grep -q 'NDS_PLATFORM_RUN_ON_VM' \
       && awk '/^# This machine only/,/^# Menu control/' <<<"$grouped" | grep -q 'NDS_PLATFORM_VM_TYPE' \
       && ! awk '/^# Configuration — portable/,/^# This machine only/' <<<"$grouped" | grep -q 'NDS_PLATFORM_'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: platform vars in machine-only section"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: platform vars not in machine-only section"
    fi

    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    nds_preset_load_file "${SCRIPT_DIR}/settings/builtin/installFlake.sh" || return 0
    nds_cfg_preset_enable installFlake
    installFlake_defaults
    nds_cfg_snapshot_defaults
    export NDS_FLAKE_REPO_URL="git@github.com:org/flake.git"
    export NDS_INSTALL_MODE="remote"
    nds_cfg_apply_env_all
    grouped="$(nds_cfg_export_grouped)"
    if grep -q 'NDS_FLAKE_REPO_URL="git@github.com:org/flake.git"' <<<"$grouped" \
       && grep -q 'NDS_INSTALL_MODE="remote"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env apply + export: FLAKE_REPO_URL and INSTALL_MODE when set"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env apply + export: missing FLAKE_REPO_URL or INSTALL_MODE"
    fi

    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    nds_preset_load_file "${SCRIPT_DIR}/settings/builtin/installFlake.sh" || return 0
    nds_cfg_preset_enable installFlake
    installFlake_defaults
    nds_cfg_snapshot_defaults
    unset NDS_FLAKE_REPO_URL NDS_FLAKE_LOCAL_PATH NDS_FLAKE_SOURCE
    export NDS_FLAKE_LOCATION="git@github.com:org/via-location.git"
    nds_cfg_apply_env_all
    if [[ "$(nds_cfg_get FLAKE_REPO_URL)" == "git@github.com:org/via-location.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ FLAKE_LOCATION syncs to FLAKE_REPO_URL via env"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ FLAKE_LOCATION sync failed (got: $(nds_cfg_get FLAKE_REPO_URL))"
    fi

    CONFIG_DATA[NETWORK_HOSTNAME]="menu-skip-host"
    export NDS_SKIP_MENU=true NDS_AUTO_CONFIRM=true
    if nds_cfg_menu_or_skip network </dev/null 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ menu_or_skip: skips when env flags set and preset valid"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ menu_or_skip: should skip with NDS_SKIP_MENU + valid network preset"
    fi
    unset NDS_SKIP_MENU NDS_AUTO_CONFIRM

    # Scoped array bridge
    CONFIG_DATA=([FLAKE_HOST]="ctl" [DISK_TARGET]="/dev/sda" [ENCRYPTION]="false")
    if mapped=$(nds_cfg_scope_for_key FLAKE_HOST) && [[ "$mapped" == $'FLAKE\tHOST' ]] \
        && flat=$(nds_cfg_flat_key_for_scope FLAKE HOST) && [[ "$flat" == "FLAKE_HOST" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ scoped key map: FLAKE_HOST ↔ FLAKE/HOST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ scoped key map: FLAKE_HOST"
    fi

    nds_cfg_sync_store_to_scoped
    if [[ "${NDS_FLAKE[HOST]:-}" == "ctl" && "${NDS_DISK[TARGET]:-}" == "/dev/sda" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ sync store → scoped arrays"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ sync store → scoped arrays"
    fi

    NDS_FLAKE[HOST]="newhost"
    nds_cfg_sync_scoped_to_store
    if [[ "$(nds_cfg_get FLAKE_HOST)" == "newhost" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ sync scoped → store"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ sync scoped → store"
    fi

    block="$(nds_cfg_export_scoped_block FLAKE)"
    if grep -q 'declare -A NDS_FLAKE' <<<"$block" && grep -q '\[HOST\]=' <<<"$block"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ export scoped declare -A block"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ export scoped declare -A block"
    fi

    # Screen export: modified env only (no declare -A)
    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    CONFIG_DATA[ENCRYPTION_ENABLED]="true"
    CONFIG_DATA[DISK_TARGET]="/dev/sda"
    nds_cfg_snapshot_defaults
    CONFIG_DATA[ENCRYPTION_ENABLED]="false"
    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    local modified
    modified="$(nds_cfg_export_modified)"
    if grep -q 'NDS_ENCRYPTION_ENABLED="false"' <<<"$modified" \
       && grep -q 'NDS_FLAKE_HOST="control-toolkit"' <<<"$modified" \
       && ! grep -q 'declare -A' <<<"$modified"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ export_modified: changed env only, no arrays"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ export_modified: expected changed env only"
    fi
}
