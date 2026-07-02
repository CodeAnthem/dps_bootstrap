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
}
