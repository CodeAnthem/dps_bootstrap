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
    test_9_emoji_customization
    test_10_tag_customization
    test_11_timestamp_toggle
    test_12_datestamp_toggle
    test_13_combined_settings
    test_14_indent_customization
    test_15_default_message

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

    debug_disable silent  # Ensure starting state

    debug_enable silent
    assert "debug_is_enabled" "Debug enabled"

    debug_disable silent
    assert "! debug_is_enabled" "Debug disabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_3_toggle() {
    test_start "Toggle State"

    debug_disable silent
    assert "! debug_is_enabled" "Starting disabled"

    debug_toggle silent
    assert "debug_is_enabled" "Toggled to enabled"

    debug_toggle silent
    assert "! debug_is_enabled" "Toggled back to disabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_4_debug_set() {
    test_start "Set State with Various Values"

    debug_state false silent
    assert "! debug_is_enabled" "Set to false"

    debug_state true silent
    assert "debug_is_enabled" "Set to true"

    debug_state 0 silent
    assert "! debug_is_enabled" "Set to 0"

    debug_state 1 silent
    assert "debug_is_enabled" "Set to 1"

    debug_state off silent
    assert "! debug_is_enabled" "Set to off"

    debug_state on silent
    assert "debug_is_enabled" "Set to on"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_5_is_enabled() {
    test_start "Check Is Enabled"

    debug_disable silent
    if debug_is_enabled; then
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: debug_is_enabled returns false when disabled\n'
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ debug_is_enabled returns false when disabled\n'
    fi

    debug_enable silent
    if debug_is_enabled; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ debug_is_enabled returns true when enabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: debug_is_enabled returns true when enabled\n'
    fi

    debug_disable silent
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
    debug_set --file "$tmpfile"

    # Enable debug and write message
    debug_enable silent
    debug "Test message for file"

    # Check if file contains the message
    local content
    content=$(cat "$tmpfile" 2>/dev/null)
    assert_contains "$content" "Test message for file" "Message written to file"
    assert_contains "$content" "[DEBUG]" "Contains DEBUG prefix"

    # Disable file output
    debug_set --file ""

    # Clean up
    rm -f "$tmpfile"
    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_8_get_state() {
    test_start "Get State String"

    debug_disable silent
    local state
    state=$(debug_get_state)
    assert_equal "$state" "disabled" "State is 'disabled'"

    debug_enable silent
    state=$(debug_get_state)
    assert_equal "$state" "enabled" "State is 'enabled'"

    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_9_emoji_customization() {
    test_start "Emoji Customization"

    debug_enable silent

    # Set custom emoji
    debug_set --emoji " 🔧"

    # Capture output
    local output
    output=$(debug "Test custom emoji" 2>&1)

    assert_contains "$output" "🔧" "Custom emoji appears in output"
    assert_contains "$output" "Test custom emoji" "Message present"

    # Reset to default
    debug_set --emoji " 🚧"
    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_10_tag_customization() {
    test_start "Tag Customization"

    debug_enable silent

    # Set custom tag
    debug_set --tag " [CUSTOM] -"

    # Capture output
    local output
    output=$(debug "Test custom tag" 2>&1)

    assert_contains "$output" "[CUSTOM]" "Custom tag appears in output"
    assert_contains "$output" "Test custom tag" "Message present"

    # Reset to default
    debug_set --tag " [DEBUG] -"
    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_11_timestamp_toggle() {
    test_start "Timestamp Toggle"

    debug_enable silent

    # Disable timestamp
    debug_set --timestamp 0
    local output_no_ts
    output_no_ts=$(debug "No timestamp" 2>&1)

    # Should not contain time pattern (HH:MM:SS)
    if [[ "$output_no_ts" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "false" "No timestamp when disabled"
    else
        assert "true" "No timestamp when disabled"
    fi

    # Enable timestamp
    debug_set --timestamp 1
    local output_with_ts
    output_with_ts=$(debug "With timestamp" 2>&1)

    # Should contain time pattern
    if [[ "$output_with_ts" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "true" "Timestamp present when enabled"
    else
        assert "false" "Timestamp present when enabled"
    fi

    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_12_datestamp_toggle() {
    test_start "Datestamp Toggle"

    debug_enable silent

    # Disable datestamp (time only)
    debug_set --datestamp 0
    local output_time_only
    output_time_only=$(debug "Time only" 2>&1)

    # Should not contain date pattern (YYYY-MM-DD)
    if [[ "$output_time_only" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "false" "No date when datestamp disabled"
    else
        assert "true" "No date when datestamp disabled"
    fi

    # Enable datestamp (full datetime)
    debug_set --datestamp 1
    local output_full
    output_full=$(debug "Full datetime" 2>&1)

    # Should contain date pattern
    if [[ "$output_full" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "true" "Date present when datestamp enabled"
    else
        assert "false" "Date present when datestamp enabled"
    fi

    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_13_combined_settings() {
    test_start "Combined Settings (No Timestamp, Custom Emoji/Tag)"

    debug_enable silent

    # Test setting multiple options at once
    debug_set --timestamp 0 --emoji " ⚡" --tag " [TEST] -"

    local output
    output=$(debug "Combined test" 2>&1)

    # Should have custom emoji and tag
    assert_contains "$output" "⚡" "Custom emoji present"
    assert_contains "$output" "[TEST]" "Custom tag present"
    assert_contains "$output" "Combined test" "Message present"

    # Should not have timestamp
    if [[ "$output" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "false" "No timestamp in combined mode"
    else
        assert "true" "No timestamp in combined mode"
    fi

    # Reset all to defaults (using single call)
    debug_set --timestamp 1 --datestamp 1 --emoji " 🚧" --tag " [DEBUG] -"
    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_14_indent_customization() {
    test_start "Indent Customization"

    debug_enable silent

    # Test default indent (1 space)
    local output_default
    output_default=$(debug "Default indent" 2>&1)
    # Default has 1 leading space before timestamp
    assert_contains "$output_default" " " "Has leading space by default"

    # Set to 0 (no indent)
    debug_set --indent 0
    local output_no_indent
    output_no_indent=$(debug "No indent" 2>&1)
    # Should start immediately with date or timestamp
    if [[ "$output_no_indent" =~ ^[0-9] ]]; then
        assert "true" "No indent - starts with timestamp"
    else
        assert "false" "No indent - starts with timestamp"
    fi

    # Set to 5 spaces
    debug_set --indent 5
    local output_five
    output_five=$(debug "Five spaces" 2>&1)
    # Should have 5 leading spaces
    if [[ "$output_five" =~ ^[[:space:]]{5} ]]; then
        assert "true" "Five spaces indent applied"
    else
        assert "false" "Five spaces indent applied"
    fi

    # Reset to default
    debug_set --indent 1
    debug_disable silent
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_15_default_message() {
    test_start "Default Message (No Argument Passed)"

    debug_enable silent

    # Call debug without message - should show caller info
    local output
    output=$(debug 2>&1)

    # Should contain the default message parts
    assert_contains "$output" "<No message was passed>" "Default message shown"
    assert_contains "$output" "called from" "Shows caller info"
    assert_contains "$output" "#" "Shows line number"

    # Call debug with empty string - should use default
    output=$(debug "" 2>&1)
    assert_contains "$output" "<No message was passed>" "Empty string triggers default message"

    debug_disable silent
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
    printf '║  Total Tests:    %-60s  ║\n' "$TEST_COUNT"
    printf '║  Total Asserts:  %-60s  ║\n' "$((TEST_PASSED + TEST_FAILED))"
    printf '║  ✓ Passed:       %-60s  ║\n' "$TEST_PASSED"
    printf '║  ✗ Failed:       %-60s  ║\n' "$TEST_FAILED"
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
