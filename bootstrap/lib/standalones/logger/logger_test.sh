#!/usr/bin/env bash
# ==================================================================================================
# Logger - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-12
# Description:   Test suite for Logger standalone feature
# Feature:       Tests for logging levels, file output, timestamps, configuration
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
    
    test_1_logging_functions
    test_2_file_output
    test_3_timestamp_format
    test_4_timestamp_toggle
    test_5_clear_file
    test_6_console_functions
    
    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
test_1_logging_functions() {
    test_start "Logging Functions Execute Without Error"
    
    # All logging functions should execute without errors
    local exit_code=0
    
    info "Test info message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "info() executes"
    
    warn "Test warn message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "warn() executes"
    
    error "Test error message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "error() executes"
    
    fatal "Test fatal message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "fatal() executes"
    
    success "Test success message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "success() executes"
    
    validation_error "Test validation message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "validation_error() executes"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_2_file_output() {
    test_start "File Output"
    
    local tmpfile
    tmpfile=$(mktemp)
    
    # Set output file
    log_set_output_file "$tmpfile" 2>/dev/null
    
    # Write messages
    info "Test info message"
    warn "Test warn message"
    error "Test error message"
    
    # Check file content
    local content
    content=$(cat "$tmpfile" 2>/dev/null)
    
    assert_contains "$content" "Test info message" "Info message in file"
    assert_contains "$content" "Test warn message" "Warn message in file"
    assert_contains "$content" "Test error message" "Error message in file"
    assert_contains "$content" "[INFO]" "Contains INFO prefix"
    assert_contains "$content" "[WARN]" "Contains WARN prefix"
    assert_contains "$content" "[ERROR]" "Contains ERROR prefix"
    
    # Get output file
    local file
    file=$(log_get_output_file)
    assert_equal "$file" "$tmpfile" "Get output file returns correct path"
    
    # Disable file output
    log_set_output_file "" 2>/dev/null
    
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_3_timestamp_format() {
    test_start "Timestamp Format"
    
    local tmpfile
    tmpfile=$(mktemp)
    
    # Set custom format (time only)
    log_set_timestamp_format '%H:%M:%S' 2>/dev/null
    log_set_output_file "$tmpfile" 2>/dev/null
    
    info "Test message with custom timestamp"
    
    local content
    content=$(cat "$tmpfile" 2>/dev/null)
    
    # Check format (should match HH:MM:SS pattern)
    if [[ "$content" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Custom timestamp format applied\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Custom timestamp format not applied\n'
    fi
    
    # Reset to default
    log_set_timestamp_format '%Y-%m-%d %H:%M:%S' 2>/dev/null
    log_set_output_file "" 2>/dev/null
    
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_4_timestamp_toggle() {
    test_start "Timestamp Toggle"
    
    local tmpfile
    tmpfile=$(mktemp)
    
    # Disable timestamps
    log_set_timestamp false 2>/dev/null
    log_set_output_file "$tmpfile" 2>/dev/null
    
    info "Message without timestamp"
    
    local content
    content=$(cat "$tmpfile" 2>/dev/null)
    
    # Should NOT contain date pattern
    if [[ ! "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps disabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps still present\n'
    fi
    
    # Re-enable timestamps
    log_set_timestamp true 2>/dev/null
    : > "$tmpfile"  # Clear file
    
    info "Message with timestamp"
    
    content=$(cat "$tmpfile" 2>/dev/null)
    
    # Should contain timestamp
    if [[ "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps re-enabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps not present\n'
    fi
    
    log_set_output_file "" 2>/dev/null
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_5_clear_file() {
    test_start "Clear Log File"
    
    local tmpfile
    tmpfile=$(mktemp)
    
    # Write some content
    log_set_output_file "$tmpfile" 2>/dev/null
    info "First message"
    info "Second message"
    
    local size_before
    size_before=$(wc -c < "$tmpfile")
    
    assert "[ $size_before -gt 0 ]" "File has content before clear"
    
    # Clear file
    log_clear_file 2>/dev/null
    
    local size_after
    size_after=$(wc -c < "$tmpfile")
    
    assert_equal "$size_after" "0" "File is empty after clear"
    
    log_set_output_file "" 2>/dev/null
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_6_console_functions() {
    test_start "Console Functions"
    
    # These should execute without error
    local exit_code=0
    
    console "Test console message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "console() executes"
    
    consolef "Test formatted %s" "message" 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "consolef() executes"
    
    new_line 2>/dev/null || exit_code=1
    assert_equal "$exit_code" "0" "new_line() executes"
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
