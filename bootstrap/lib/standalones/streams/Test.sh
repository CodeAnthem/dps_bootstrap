#!/usr/bin/env bash
# ==================================================================================================
# Streams - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-13 | Modified: 2025-11-13
# Description:   Test suite for Streams standalone feature
# Feature:       Tests for channels, functions, routing, format settings
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
    printf '║                          STREAMS - TEST SUITE                                  ║\n'
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'

    test_1_predefined_functions
    test_2_channel_routing_logger
    test_3_channel_routing_debug
    test_4_file_output
    test_5_format_console_timestamp
    test_6_format_console_indent
    test_7_format_file_settings
    test_8_emoji_suppression
    test_9_function_management
    test_10_nop_functions
    test_11_exit_codes
    test_12_stdout_safety
    test_13_combined_settings

    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
test_1_predefined_functions() {
    test_start "Predefined Functions Exist and Execute"

    # Test all predefined functions exist
    local output

    output=$(output "Output test" 2>&1)
    assert_contains "$output" "Output test" "output() executes"

    output=$(info "Info test" 2>&1)
    assert_contains "$output" "[INFO]" "info() has INFO tag"

    output=$(warn "Warn test" 2>&1)
    assert_contains "$output" "[WARN]" "warn() has WARN tag"

    output=$(error "Error test" 2>&1)
    assert_contains "$output" "[ERROR]" "error() has ERROR tag"

    output=$(pass "Pass test" 2>&1)
    assert_contains "$output" "[PASS]" "pass() has PASS tag"

    # Debug is NOP by default
    output=$(debug "Debug test" 2>&1)
    assert_equal "$output" "" "debug() is NOP by default"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_2_channel_routing_logger() {
    test_start "Channel Routing - Logger Channel (fd3)"

    # Logger channel should route to fd3
    # Capture fd3 output
    local output
    output=$(info "Test message" 3>&1 1>/dev/null 2>/dev/null)
    
    assert_contains "$output" "Test message" "Logger channel routes to fd3"
    assert_contains "$output" "[INFO]" "Logger channel includes tag"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_3_channel_routing_debug() {
    test_start "Channel Routing - Debug Channel (fd4)"

    # Enable debug first
    stream_function debug --enable

    # Debug channel should route to fd4
    local output
    output=$(debug "Debug message" 4>&1 1>/dev/null 2>/dev/null 3>/dev/null)
    
    assert_contains "$output" "Debug message" "Debug channel routes to fd4"
    assert_contains "$output" "[DEBUG]" "Debug channel includes tag"

    # Disable debug for other tests
    stream_function debug --disable
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_4_file_output() {
    test_start "File Output"

    local tmpfile
    tmpfile=$(mktemp)

    # Set file for logger channel
    stream_set_channel logger --file-path "$tmpfile"

    # Write messages
    info "Test info message"
    warn "Test warn message"

    # Check file content
    local content
    content=$(cat "$tmpfile")

    assert_contains "$content" "Test info message" "Info message in file"
    assert_contains "$content" "Test warn message" "Warn message in file"
    assert_contains "$content" "[INFO]" "File contains INFO tag"
    assert_contains "$content" "[WARN]" "File contains WARN tag"

    # Clear file path
    stream_set_channel logger --file-path ""

    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_5_format_console_timestamp() {
    test_start "Format - Console Timestamp Toggle"

    # Disable timestamps
    stream_set_format console --time 0 --date 0

    local output
    output=$(info "No timestamp" 2>&1)

    # Should NOT contain date pattern
    if [[ ! "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps disabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps still present\n'
    fi

    # Re-enable
    stream_set_format console --time 1 --date 1

    output=$(info "With timestamp" 2>&1)

    # Should contain timestamp
    if [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps re-enabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps not present\n'
    fi
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_6_format_console_indent() {
    test_start "Format - Console Indentation"

    # Set indent to 0
    stream_set_format console --indent 0

    local output
    output=$(info "No indent" 2>&1)

    # Should start with date (no leading space)
    if [[ "$output" =~ ^[0-9] ]]; then
        assert "true" "No indent - starts with date"
    else
        assert "false" "No indent - starts with date"
    fi

    # Set indent to 5
    stream_set_format console --indent 5

    output=$(info "Five spaces" 2>&1)

    # Should have 5 leading spaces
    if [[ "$output" =~ ^[[:space:]]{5} ]]; then
        assert "true" "Five spaces indent applied"
    else
        assert "false" "Five spaces indent applied"
    fi

    # Reset to default
    stream_set_format console --indent 1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_7_format_file_settings() {
    test_start "Format - File Settings"

    local tmpfile
    tmpfile=$(mktemp)

    # Configure file format: time only, no date
    stream_set_format file --date 0 --time 1
    stream_set_channel logger --file-path "$tmpfile"

    info "Test message"

    local content
    content=$(cat "$tmpfile")

    # Should not contain full date
    if [[ ! "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "true" "File format excludes date"
    else
        assert "false" "File format excludes date"
    fi

    # Should contain time
    if [[ "$content" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "true" "File format includes time"
    else
        assert "false" "File format includes time"
    fi

    # Reset
    stream_set_format file --date 1 --time 1
    stream_set_channel logger --file-path ""

    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_8_emoji_suppression() {
    test_start "Emoji Suppression"

    # Enable emoji suppression
    stream_set_format --suppress-emojis 1

    local output
    output=$(info "No emoji" 2>&1)

    # Should not contain emoji
    if [[ "$output" =~ ℹ️ ]]; then
        assert "false" "Emoji suppressed"
    else
        assert "true" "Emoji suppressed"
    fi

    # Should still contain tag
    assert_contains "$output" "[INFO]" "Tag still present"

    # Disable suppression
    stream_set_format --suppress-emojis 0

    output=$(info "With emoji" 2>&1)
    assert_contains "$output" "ℹ️" "Emoji restored"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_9_function_management() {
    test_start "Function Management - Create Custom Function"

    # Create custom function
    stream_function "trace" --emoji " 🔍" --tag " [TRACE] -" --channel "debug" --exit -1

    # Enable it (since debug channel might be off)
    stream_function trace --enable

    local output
    output=$(trace "Trace message" 4>&1 1>/dev/null 2>/dev/null 3>/dev/null)

    assert_contains "$output" "[TRACE]" "Custom function has correct tag"
    assert_contains "$output" "🔍" "Custom function has correct emoji"
    assert_contains "$output" "Trace message" "Custom function message present"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_10_nop_functions() {
    test_start "NOP Functions (Disable/Enable)"

    # Disable warn function
    stream_function warn --disable

    local output
    output=$(warn "Should not appear" 2>&1)

    assert_equal "$output" "" "Disabled function produces no output"

    # Re-enable
    stream_function warn --enable

    output=$(warn "Should appear" 2>&1)
    assert_contains "$output" "Should appear" "Re-enabled function works"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_11_exit_codes() {
    test_start "Exit Codes"

    # Fatal should have exit code 1 (test in subshell)
    local exit_code
    ( fatal "Fatal error" 2>/dev/null )
    exit_code=$?

    assert_equal "$exit_code" "1" "fatal() exits with code 1"

    # Create custom function with exit code 42
    stream_function "abort" --emoji " ❌" --tag " [ABORT] -" --channel "stderr" --exit 42

    ( abort "Abort" 2>/dev/null )
    exit_code=$?

    assert_equal "$exit_code" "42" "Custom exit code works"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_12_stdout_safety() {
    test_start "Stdout Channel Safety (Cannot Disable Console)"

    # Try to disable console for stdout - should fail
    stream_set_channel stdout --console 0 2>/dev/null
    local result=$?

    assert_equal "$result" "1" "Preventing stdout console disable returns error"

    # Verify stdout console is still enabled
    local console_setting="${__STREAMS_CONFIG[CHANNEL::stdout::CONSOLE]}"
    assert_equal "$console_setting" "1" "Stdout console remains enabled"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_13_combined_settings() {
    test_start "Combined Settings (Multiple Options)"

    local tmpfile
    tmpfile=$(mktemp)

    # Set multiple options at once
    stream_set_format console --time 1 --date 0 --indent 0
    stream_set_format --suppress-emojis 1
    stream_set_channel logger --file-path "$tmpfile"

    local output
    output=$(info "Combined test" 2>&1)

    # Should have NO date
    if [[ ! "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "true" "No date in combined mode"
    else
        assert "false" "No date in combined mode"
    fi

    # Should have time
    if [[ "$output" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "true" "Time present in combined mode"
    else
        assert "false" "Time present in combined mode"
    fi

    # Should have no emoji
    if [[ "$output" =~ ℹ️ ]]; then
        assert "false" "No emoji in combined mode"
    else
        assert "true" "No emoji in combined mode"
    fi

    # File should also have content
    local content
    content=$(cat "$tmpfile")
    assert_contains "$content" "Combined test" "File output works in combined mode"

    # Reset to defaults
    stream_set_format console --time 1 --date 1 --indent 1
    stream_set_format --suppress-emojis 0
    stream_set_channel logger --file-path ""

    rm -f "$tmpfile"
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
