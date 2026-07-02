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
}
