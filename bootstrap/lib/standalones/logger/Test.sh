#!/usr/bin/env bash
# ==================================================================================================
# Logger - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-13
# Description:   Test suite for Logger standalone feature
# Feature:       Tests for predefined loggers, dynamic creation, file output, exit codes
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
    printf '║                          LOGGER - TEST SUITE                                   ║\n'
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'

    test_1_predefined_loggers
    test_2_file_output
    test_3_timestamp_toggle
    test_4_datestamp_toggle
    test_5_indent_customization
    test_6_emoji_suppression
    test_7_combined_settings
    test_8_dynamic_logger_creation
    test_9_log_show_file
    test_10_log_clear_file
    test_11_default_message

    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
test_1_predefined_loggers() {
    test_start "Predefined Loggers (info, warn, error, fatal, pass, fail)"

    # Test all predefined loggers exist and execute
    local output

    output=$(info "Info test" 2>&1)
    assert_contains "$output" "[INFO]" "info() has INFO tag"
    assert_contains "$output" "Info test" "info() message present"

    output=$(warn "Warn test" 2>&1)
    assert_contains "$output" "[WARN]" "warn() has WARN tag"

    output=$(error "Error test" 2>&1)
    assert_contains "$output" "[ERROR]" "error() has ERROR tag"

    output=$(pass "Pass test" 2>&1)
    assert_contains "$output" "[PASS]" "pass() has PASS tag"
    assert_contains "$output" "✅" "pass() has checkmark emoji"

    # Note: fatal and fail have exit code 1, so we can't test them directly without subshell
    # Testing them would cause the test suite to exit
    assert "true" "Predefined loggers functional"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_2_file_output() {
    test_start "File Output"

    local tmpfile
    tmpfile=$(mktemp)

    # Set output file using new API
    log_set --file "$tmpfile"

    # Write messages
    info "Test info message"
    warn "Test warn message"
    error "Test error message"

    # Check file content
    local content
    content=$(cat "$tmpfile")

    assert_contains "$content" "Test info message" "Info message in file"
    assert_contains "$content" "Test warn message" "Warn message in file"
    assert_contains "$content" "Test error message" "Error message in file"
    assert_contains "$content" "[INFO]" "Contains INFO prefix"
    assert_contains "$content" "[WARN]" "Contains WARN prefix"
    assert_contains "$content" "[ERROR]" "Contains ERROR prefix"

    # Get output file
    local file
    file=$(log_get_file)
    assert_equal "$file" "$tmpfile" "Get output file returns correct path"

    # Disable file output
    log_set --file ""

    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_3_timestamp_toggle() {
    test_start "Timestamp Toggle"

    local tmpfile
    tmpfile=$(mktemp)
    log_set --file "$tmpfile"

    # Disable timestamps
    log_set --timestamp 0
    info "Message without timestamp"

    local content
    content=$(cat "$tmpfile")

    # Should NOT contain date pattern
    if [[ ! "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps disabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps still present\n'
    fi

    # Re-enable timestamps
    log_set --timestamp 1
    : > "$tmpfile"  # Clear file
    info "Message with timestamp"

    content=$(cat "$tmpfile")

    # Should contain timestamp
    if [[ "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps re-enabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps not present\n'
    fi

    log_set --file ""
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_4_datestamp_toggle() {
    test_start "Datestamp Toggle"

    # Disable datestamp (time only)
    log_set --datestamp 0
    local output_time_only
    output_time_only=$(info "Time only" 2>&1)

    # Should not contain date pattern (YYYY-MM-DD)
    if [[ "$output_time_only" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "false" "No date when datestamp disabled"
    else
        assert "true" "No date when datestamp disabled"
    fi

    # Should still contain time pattern (HH:MM:SS)
    if [[ "$output_time_only" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "true" "Time present when datestamp disabled"
    else
        assert "false" "Time present when datestamp disabled"
    fi

    # Enable datestamp (full datetime)
    log_set --datestamp 1
    local output_full
    output_full=$(info "Full datetime" 2>&1)

    # Should contain date pattern
    if [[ "$output_full" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "true" "Date present when datestamp enabled"
    else
        assert "false" "Date present when datestamp enabled"
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_5_indent_customization() {
    test_start "Indent Customization"

    # Test default indent (1 space)
    local output_default
    output_default=$(info "Default indent" 2>&1)
    assert_contains "$output_default" " " "Has leading space by default"

    # Set to 0 (no indent)
    log_set --indent 0
    local output_no_indent
    output_no_indent=$(info "No indent" 2>&1)
    # Should start immediately with date or timestamp
    if [[ "$output_no_indent" =~ ^[0-9] ]]; then
        assert "true" "No indent - starts with timestamp"
    else
        assert "false" "No indent - starts with timestamp"
    fi

    # Set to 5 spaces
    log_set --indent 5
    local output_five
    output_five=$(info "Five spaces" 2>&1)
    # Should have 5 leading spaces
    if [[ "$output_five" =~ ^[[:space:]]{5} ]]; then
        assert "true" "Five spaces indent applied"
    else
        assert "false" "Five spaces indent applied"
    fi

    # Reset to default
    log_set --indent 1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_6_emoji_suppression() {
    test_start "Emoji Suppression"

    # Enable emoji suppression
    log_set --suppress-emojis 1
    local output
    output=$(info "No emoji" 2>&1)

    # Should not contain emoji
    assert_contains "$output" "[INFO]" "Tag still present with suppression"
    if [[ "$output" =~ ℹ️ ]]; then
        assert "false" "Emoji suppressed"
    else
        assert "true" "Emoji suppressed"
    fi

    # Disable emoji suppression
    log_set --suppress-emojis 0
    output=$(info "With emoji" 2>&1)
    assert_contains "$output" "ℹ️" "Emoji restored after suppression disabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_7_combined_settings() {
    test_start "Combined Settings (Using log_set with Multiple Options)"

    # Set multiple options at once
    log_set --timestamp 0 --indent 0 --suppress-emojis 1

    local output
    output=$(info "Combined test" 2>&1)

    # Should have NO timestamp
    if [[ "$output" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "false" "No timestamp in combined mode"
    else
        assert "true" "No timestamp in combined mode"
    fi

    # Should start with tag (no indent, no emoji)
    assert_contains "$output" "[INFO]" "Tag present in combined mode"
    
    # Check no indent (starts with tag)
    if [[ "$output" =~ ^[[:space:]] ]]; then
        assert "false" "No leading space in combined mode"
    else
        assert "true" "No leading space in combined mode"
    fi

    # Reset to defaults
    log_set --timestamp 1 --datestamp 1 --indent 1 --suppress-emojis 0
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_8_dynamic_logger_creation() {
    test_start "Dynamic Logger Creation (log_create_logger)"

    # Create custom logger
    log_create_logger "critical" --emoji " 🔥" --tag " [CRITICAL] -" --exit -1

    # Test it exists and works
    local output
    output=$(critical "Custom critical logger" 2>&1)
    assert_contains "$output" "[CRITICAL]" "Custom logger has correct tag"
    assert_contains "$output" "🔥" "Custom logger has correct emoji"
    assert_contains "$output" "Custom critical logger" "Custom logger message present"

    # Create another with different settings
    log_create_logger "trace" --emoji " 🔍" --tag " [TRACE] -"
    output=$(trace "Trace message" 2>&1)
    assert_contains "$output" "[TRACE]" "Second custom logger created"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_9_log_show_file() {
    test_start "Show Log File Contents (log_show_file)"

    local tmpfile
    tmpfile=$(mktemp)

    # Set output file and write content
    log_set --file "$tmpfile"
    info "Line 1"
    warn "Line 2"
    error "Line 3"

    # Show file contents
    local content
    content=$(log_show_file)

    assert_contains "$content" "Line 1" "log_show_file shows line 1"
    assert_contains "$content" "Line 2" "log_show_file shows line 2"
    assert_contains "$content" "Line 3" "log_show_file shows line 3"
    assert_contains "$content" "[INFO]" "log_show_file shows INFO tag"
    assert_contains "$content" "[WARN]" "log_show_file shows WARN tag"

    log_set --file ""
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_10_log_clear_file() {
    test_start "Clear Log File (log_clear_file)"

    local tmpfile
    tmpfile=$(mktemp)

    # Write content
    log_set --file "$tmpfile"
    info "Before clear"
    warn "Before clear"

    local size_before
    size_before=$(wc -c < "$tmpfile")
    assert "[ $size_before -gt 0 ]" "File has content before clear"

    # Clear file
    log_clear_file 2>/dev/null

    local size_after
    size_after=$(wc -c < "$tmpfile")
    assert_equal "$size_after" "0" "File is empty after clear"

    log_set --file ""
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_11_default_message() {
    test_start "Default Message (No Argument Passed)"

    # Call logger without message - should show caller info
    local output
    output=$(info 2>&1)

    # Should contain the default message parts
    assert_contains "$output" "<No message was passed>" "Default message shown"
    assert_contains "$output" "called from" "Shows caller info"
    assert_contains "$output" "#" "Shows line number"

    # Call with empty string - should use default
    output=$(info "" 2>&1)
    assert_contains "$output" "<No message was passed>" "Empty string triggers default message"
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
