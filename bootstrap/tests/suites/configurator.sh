#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configurator smoke tests (read-only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-02
# ==================================================================================================

suite_configurator() {
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

    nds_config_snapshot_defaults
    CONFIG_DATA[DISK_TARGET]="/dev/testdisk"
    CONFIG_DATA[REGION_TIMEZONE]="Europe/Test"
    local grouped
    grouped="$(nds_configurator_config_export_grouped)"
    if [[ "$(grep -c '^export ' <<<"$grouped")" -le 2 ]] \
       && grep -q 'NDS_REGION_TIMEZONE="Europe/Test"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: <=2 single-line commands, portable value present"
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

    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    nds_preset_load_file "${SCRIPT_DIR}/presets/installFlake.sh" || return 0
    nds_configurator_preset_enable installFlake
    installFlake_defaults
    nds_config_snapshot_defaults
    export NDS_FLAKE_REPO_URL="git@github.com:org/flake.git"
    export NDS_INSTALL_MODE="remote"
    nds_cfg_apply_env_all
    grouped="$(nds_configurator_config_export_grouped)"
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
    nds_preset_load_file "${SCRIPT_DIR}/presets/installFlake.sh" || return 0
    nds_configurator_preset_enable installFlake
    installFlake_defaults
    nds_config_snapshot_defaults
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
    if nds_configurator_menu_or_skip network </dev/null 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ menu_or_skip: skips when env flags set and preset valid"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ menu_or_skip: should skip with NDS_SKIP_MENU + valid network preset"
    fi
    unset NDS_SKIP_MENU NDS_AUTO_CONFIRM
}
