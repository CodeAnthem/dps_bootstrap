#!/usr/bin/env bash
# ==================================================================================================
# Debugger - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-12
# Description:   Test suite for Debugger standalone feature
# Feature:       Tests for debug output, state management, custom variables, file output
# ==================================================================================================
# shellcheck disable=SC1090  # Can't follow non-constant source
# shellcheck disable=SC1091  # Source not following

# ==================================================================================================
# EXECUTION GUARD
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    printf 'Error: This test script must be executed, not sourced\n -> File: %s\n' "${0}" >&2
    return 1
fi

# ==================================================================================================
# PATH RESOLUTION & FEATURE LOADING
# ==================================================================================================

SCRIPT_DIR="${BASH_SOURCE[0]}"
while [[ -h "$SCRIPT_DIR" ]]; do
    SCRIPT_DIR="$(readlink "$SCRIPT_DIR")"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_DIR")" && pwd)"

FOLDER_NAME="$(basename "$SCRIPT_DIR")"
FEATURE_FILE="${SCRIPT_DIR}/${FOLDER_NAME}.sh"

if [[ ! -f "$FEATURE_FILE" ]]; then
    printf 'Error: Feature file not found: %s\n' "$FEATURE_FILE" >&2
    exit 1
fi

source "$FEATURE_FILE" || {
    printf 'Error: Failed to source feature file: %s\n' "$FEATURE_FILE" >&2
    exit 1
}

# ==================================================================================================
# MAIN TEST ORCHESTRATOR
# ==================================================================================================

main() {
    printf '╔════════════════════════════════════════════════════════════════════════════════╗\n'
    printf '║                         DEBUGGER - TEST SUITE                                  ║\n'
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'
    
    test_1_default_state
    test_2_enable_disable
    test_3_toggle
    test_4_debug_set
    test_5_is_enabled
    test_6_custom_variable_name
    test_7_file_output
    test_8_get_state
    
    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
test_1_default_state() {
    test_start "Default State (Disabled)"
    
    # Debug should be disabled by default
    assert "! debug_is_enabled" "Debug disabled by default"
    
    local state
    state=$(debug_get_state)
    assert_equal "$state" "disabled" "State reports 'disabled'"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_2_enable_disable() {
    test_start "Enable and Disable"
    
    debug_disable  # Ensure starting state
    
    debug_enable
    assert "debug_is_enabled" "Debug enabled"
    
    debug_disable
    assert "! debug_is_enabled" "Debug disabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_3_toggle() {
    test_start "Toggle State"
    
    debug_disable
    assert "! debug_is_enabled" "Starting disabled"
    
    debug_toggle
    assert "debug_is_enabled" "Toggled to enabled"
    
    debug_toggle
    assert "! debug_is_enabled" "Toggled back to disabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_4_debug_set() {
    test_start "Set State with Various Values"
    
    debug_set false
    assert "! debug_is_enabled" "Set to false"
    
    debug_set true
    assert "debug_is_enabled" "Set to true"
    
    debug_set 0
    assert "! debug_is_enabled" "Set to 0"
    
    debug_set 1
    assert "debug_is_enabled" "Set to 1"
    
    debug_set off
    assert "! debug_is_enabled" "Set to off"
    
    debug_set on
    assert "debug_is_enabled" "Set to on"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_5_is_enabled() {
    test_start "Check Is Enabled"
    
    debug_disable
    if debug_is_enabled; then
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: debug_is_enabled returns false when disabled\n'
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ debug_is_enabled returns false when disabled\n'
    fi
    
    debug_enable
    if debug_is_enabled; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ debug_is_enabled returns true when enabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: debug_is_enabled returns true when enabled\n'
    fi
    
    debug_disable
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_6_custom_variable_name() {
    test_start "Custom Variable Name"
    
    # Test the variable name getter
    local var_name
    var_name=$(debug_get_var_name)
    assert_equal "$var_name" "DEBUG" "Default variable name is DEBUG"
    
    # The custom variable name is set at source time via DEBUG_VAR_NAME
    # We can't change it after sourcing, but we can test that it was set correctly
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_7_file_output() {
    test_start "File Output"
    
    local tmpfile
    tmpfile=$(mktemp)
    
    # Set output file
    debug_set_output_file "$tmpfile"
    
    # Enable debug and write message
    debug_enable
    debug "Test message for file"
    
    # Check if file contains the message
    local content
    content=$(cat "$tmpfile" 2>/dev/null)
    
    assert_contains "$content" "Test message for file" "Message written to file"
    assert_contains "$content" "[DEBUG]" "Contains DEBUG prefix"
    
    # Disable file output
    debug_set_output_file ""
    
    # Clean up
    rm -f "$tmpfile"
    debug_disable
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_8_get_state() {
    test_start "Get State String"
    
    debug_disable
    local state
    state=$(debug_get_state)
    assert_equal "$state" "disabled" "State is 'disabled'"
    
    debug_enable
    state=$(debug_get_state)
    assert_equal "$state" "enabled" "State is 'enabled'"
    
    debug_disable
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# TEST FRAMEWORK
# ==================================================================================================

declare -g TEST_COUNT=0
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0

test_start() {
    TEST_COUNT=$((TEST_COUNT + 1))
    printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    printf 'Test #%d: %s\n' "$TEST_COUNT" "$1"
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
# --------------------------------------------------------------------------------------------------

assert() {
    local condition="$1"
    local description="$2"
    
    if eval "$condition"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ %s\n' "$description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: %s\n' "$description"
        printf '    Condition: %s\n' "$condition"
    fi
}
# --------------------------------------------------------------------------------------------------

assert_equal() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ %s\n' "$description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: %s\n' "$description"
        printf "    Expected: '%s'\n" "$expected"
        printf "    Got:      '%s'\n" "$actual"
    fi
}
# --------------------------------------------------------------------------------------------------

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ %s\n' "$description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: %s\n' "$description"
        printf "    Expected to contain: '%s'\n" "$needle"
        printf "    In: '%s'\n" "$haystack"
    fi
}
# --------------------------------------------------------------------------------------------------

test_summary() {
    printf '\n╔════════════════════════════════════════════════════════════════════════════════╗\n'
    printf '║                              TEST SUMMARY                                      ║\n'
    printf '╠════════════════════════════════════════════════════════════════════════════════╣\n'
    printf '║  Total Tests:    %-58s  ║\n' "$TEST_COUNT"
    printf '║  Total Asserts:  %-58s  ║\n' "$((TEST_PASSED + TEST_FAILED))"
    printf '║  ✓ Passed:       %-58s  ║\n' "$TEST_PASSED"
    printf '║  ✗ Failed:       %-58s  ║\n' "$TEST_FAILED"
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        printf '\n✅ ALL TESTS PASSED!\n'
        return 0
    else
        printf '\n❌ SOME TESTS FAILED\n'
        return 1
    fi
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# EXECUTE TESTS
# ==================================================================================================

main "$@"
