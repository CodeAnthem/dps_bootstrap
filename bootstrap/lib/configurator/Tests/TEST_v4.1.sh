#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configurator v4.1 Test Script
# ==================================================================================================

set -euo pipefail

# Simulated library functions for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

error() { echo "ERROR: $*" >&2; }
info() { echo "INFO: $*"; }
success() { echo "SUCCESS: $*"; }
debug() { [[ "${DEBUG:-}" == "1" ]] && echo "DEBUG: $*"; }
fatal() { echo "FATAL: $*" >&2; exit 1; }
console() { echo "$*"; }

# Import function (simplified)
nds_import_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # shellcheck disable=SC1090
        source "$file"
        return 0
    else
        error "File not found: $file"
        return 1
    fi
}

nds_import_dir() {
    local dir="$1"
    local recursive="${2:-false}"
    
    if [[ ! -d "$dir" ]]; then
        error "Directory not found: $dir"
        return 1
    fi
    
    for file in "$dir"/*.sh; do
        [[ -f "$file" ]] || continue
        [[ "$(basename "$file")" == "settingTypes.sh" ]] && continue  # Skip master file
        # shellcheck disable=SC1090
        source "$file" || return 1
    done
    
    return 0
}

# =============================================================================
# TEST EXECUTION
# =============================================================================

echo "========================================"
echo "Configurator v4.1 - Basic Test"
echo "========================================"
echo ""

# Load configurator
echo "1. Loading configurator..."
source "${SCRIPT_DIR}/lib/configurator.sh" || fatal "Failed to load configurator.sh"

# Initialize
echo "2. Initializing configurator..."
nds_cfg_init || fatal "Initialization failed"
echo ""

# Test 1: Check registries
echo "3. Testing registries..."
echo "   SettingTypes: ${#CFG_ALL_SETTINGTYPES[@]}"
echo "   Presets: ${#CFG_ALL_PRESETS[@]}"
echo "   Settings: ${#CFG_ALL_SETTINGS[@]}"
echo ""

# Test 2: Get/Set values
echo "4. Testing get/set..."
nds_cfg_set HOSTNAME "test-host"
value=$(nds_cfg_get HOSTNAME)
if [[ "$value" == "test-host" ]]; then
    echo "   ✓ Get/Set works: HOSTNAME=$value"
else
    echo "   ✗ Get/Set failed: expected 'test-host', got '$value'"
fi
echo ""

# Test 3: Validation
echo "5. Testing validation..."
if nds_cfg_setting_validate HOSTNAME; then
    echo "   ✓ Validation passed for valid hostname"
else
    echo "   ✗ Validation failed for valid hostname"
fi

nds_cfg_set HOSTNAME "invalid_hostname_with_underscore" 2>/dev/null || true
if ! nds_cfg_setting_validate HOSTNAME 2>/dev/null; then
    echo "   ✓ Validation correctly rejected invalid hostname"
else
    echo "   ✗ Validation incorrectly accepted invalid hostname"
fi
echo ""

# Test 4: Export
echo "6. Testing export..."
nds_cfg_set HOSTNAME "export-test"
export_output=$(nds_cfg_export_nonDefaults)
if [[ "$export_output" == *"NDS_HOSTNAME="* ]]; then
    echo "   ✓ Export includes HOSTNAME"
else
    echo "   ✗ Export missing HOSTNAME"
fi
echo ""

# Test 5: Preset queries
echo "7. Testing preset queries..."
presets=$(nds_cfg_preset_getAllSorted)
echo "   Presets (sorted by priority):"
while IFS= read -r preset; do
    priority=$(nds_cfg_preset_get "$preset" "priority")
    echo "     - $preset (priority: $priority)"
done <<< "$presets"
echo ""

# Test 6: Setting queries
echo "8. Testing setting queries..."
echo "   Settings in 'quick' preset:"
settings=$(nds_cfg_preset_getSettings "quick")
for setting in $settings; do
    type=$(nds_cfg_setting_get "$setting" "type")
    display=$(nds_cfg_setting_get "$setting" "display")
    echo "     - $setting: $display (type: $type)"
done
echo ""

# Test 7: SettingType hooks
echo "9. Testing settingType hooks..."
validate_func=$(nds_cfg_settingType_get "hostname" "validate")
if [[ -n "$validate_func" ]]; then
    echo "   ✓ SettingType hook found: $validate_func"
else
    echo "   ✗ SettingType hook not found"
fi
echo ""

# Test 8: Country apply hook
echo "10. Testing country apply hook..."
nds_cfg_set COUNTRY "DE"
timezone=$(nds_cfg_get TIMEZONE)
locale=$(nds_cfg_get LOCALE)
if [[ "$timezone" == "Europe/Berlin" && "$locale" == "de_DE.UTF-8" ]]; then
    echo "   ✓ Country apply hook worked: TIMEZONE=$timezone, LOCALE=$locale"
else
    echo "   ✗ Country apply hook failed: TIMEZONE=$timezone, LOCALE=$locale"
fi
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "All basic tests completed."
echo "Check output above for any failures."
echo ""
echo "To test interactively:"
echo "  1. Source this script: source lib/configurator/TEST_v4.1.sh"
echo "  2. Try commands:"
echo "     - nds_cfg_get HOSTNAME"
echo "     - nds_cfg_set HOSTNAME 'myhost'"
echo "     - nds_cfg_export_nonDefaults"
echo ""
