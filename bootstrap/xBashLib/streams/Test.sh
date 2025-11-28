#!/usr/bin/env bash
# ==================================================================================================
# Streams - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-13 | Modified: 2025-11-25
# Description:   Test suite for Streams standalone feature
# Feature:       Tests for channels, functions, routing, format settings, FD management
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
# TEST FRAMEWORK - Version 1.0.0
# ==================================================================================================
# Reusable test framework with dynamic FD capturing and exit handling
# --------------------------------------------------------------------------------------------------

# Test framework globals
declare -g TEST_COUNT=0
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_FW_VERSION="1.0.0"

# --------------------------------------------------------------------------------------------------
# Capture output from all open file descriptors
# Usage: capture_all <command> [args...]
# Result: Sets CAPTURED_OUTPUT global variable
# Note: Runs command in subshell to handle exit codes safely
#       Dynamically detects open FDs at runtime (for dynamic FD management)
capture_all() {
    local tmpfile
    tmpfile=$(mktemp)
    
    # Build FD redirect string dynamically
    local fd_redirects=""
    for fd in {2..9}; do
        if { true >&$fd; } 2>/dev/null; then
            fd_redirects="$fd_redirects ${fd}>&1"
        fi
    done
    
    # Run in subshell with all FD redirects, capture to file
    # shellcheck disable=SC2086
    ( eval "\"\$@\" $fd_redirects" ) > "$tmpfile" 2>&1
    
    CAPTURED_OUTPUT=$(cat "$tmpfile")
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Start a new test
# Usage: test_start "Test Description"
test_start() {
    TEST_COUNT=$((TEST_COUNT + 1))
    printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    printf 'Test #%d: %s\n' "$TEST_COUNT" "$1"
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Assert a condition
# Usage: assert <condition> <description>
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

# --------------------------------------------------------------------------------------------------
# Assert equality
# Usage: assert_equal <actual> <expected> <description>
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

# --------------------------------------------------------------------------------------------------
# Assert substring containment
# Usage: assert_contains <haystack> <needle> <description>
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

# --------------------------------------------------------------------------------------------------
# Print test summary
# Usage: test_summary
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

# Initialize test framework
__test_fw_init

# ==================================================================================================
# END TEST FRAMEWORK v1.0.0
# ==================================================================================================

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
    test_14_special_characters
    test_15_default_message
    test_16_output_file_behavior
    test_17_fd_management

    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
test_1_predefined_functions() {
    test_start "Predefined Functions Exist and Execute"

    # Test output() - plain output, no formatting
    capture_all output "Output test message"
    assert_contains "$CAPTURED_OUTPUT" "Output test message" "output() shows message"
    assert "[[ \"$CAPTURED_OUTPUT\" != *'[INFO]'* ]]" "output() has NO tag (plain)"
    
    # Test log() - formatted output
    capture_all log "Log test message"
    assert_contains "$CAPTURED_OUTPUT" "Log test message" "log() shows message"

    capture_all info "Info test message"
    assert_contains "$CAPTURED_OUTPUT" "[INFO]" "info() has INFO tag"
    assert_contains "$CAPTURED_OUTPUT" "Info test message" "info() shows actual message"

    capture_all warn "Warn test message"
    assert_contains "$CAPTURED_OUTPUT" "[WARN]" "warn() has WARN tag"
    assert_contains "$CAPTURED_OUTPUT" "Warn test message" "warn() shows actual message"

    capture_all error "Error test message"
    assert_contains "$CAPTURED_OUTPUT" "[ERROR]" "error() has ERROR tag"
    assert_contains "$CAPTURED_OUTPUT" "Error test message" "error() shows actual message"

    capture_all pass "Pass test message"
    assert_contains "$CAPTURED_OUTPUT" "[PASS]" "pass() has PASS tag"
    assert_contains "$CAPTURED_OUTPUT" "Pass test message" "pass() shows actual message"

    capture_all debug "Debug test"
    assert "[[ -z \"$CAPTURED_OUTPUT\" ]]" "debug() is NOP by default"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_2_channel_routing_logger() {
    test_start "Channel Routing - Logger Channel (fd3)"

    # Logger channel should route to fd3
    capture_all info "Logger test message content"
    
    assert_contains "$CAPTURED_OUTPUT" "Logger test message content" "Logger channel shows actual message"
    assert_contains "$CAPTURED_OUTPUT" "[INFO]" "Logger channel includes tag"
    assert_contains "$CAPTURED_OUTPUT" "ℹ️" "Logger channel includes emoji"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_3_channel_routing_debug() {
    test_start "Channel Routing - Debug Channel (fd4)"

    # Enable debug first
    stream_function debug --enable
    
    capture_all debug "Debug channel test message"
    
    assert_contains "$CAPTURED_OUTPUT" "Debug channel test message" "Debug channel shows actual message"
    assert_contains "$CAPTURED_OUTPUT" "[DEBUG]" "Debug channel includes tag"
    assert_contains "$CAPTURED_OUTPUT" "🐛" "Debug channel includes emoji"
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
    capture_all info "Test info message"
    capture_all warn "Test warn message"

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

    capture_all info "No timestamp"

    # Should NOT contain date pattern
    if [[ ! "$CAPTURED_OUTPUT" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ Timestamps disabled\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: Timestamps still present\n'
    fi

    # Re-enable
    stream_set_format console --time 1 --date 1

    capture_all info "With timestamp"

    # Should contain timestamp
    if [[ "$CAPTURED_OUTPUT" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
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

    capture_all info "No indent"

    # Should start with date (no leading space)
    if [[ "$CAPTURED_OUTPUT" =~ ^[0-9] ]]; then
        assert "true" "No indent - starts with date"
    else
        assert "false" "No indent - starts with date"
    fi

    # Set indent to 5
    stream_set_format console --indent 5

    capture_all info "Five spaces"

    # Should have 5 leading spaces
    if [[ "$CAPTURED_OUTPUT" =~ ^[[:space:]]{5} ]]; then
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

    capture_all info "Test message"

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

    capture_all info "No emoji"

    # Should not contain emoji
    if [[ "$CAPTURED_OUTPUT" =~ ℹ️ ]]; then
        assert "false" "Emoji suppressed"
    else
        assert "true" "Emoji suppressed"
    fi

    # Should still contain tag
    assert_contains "$CAPTURED_OUTPUT" "[INFO]" "Tag still present"

    # Disable suppression
    stream_set_format --suppress-emojis 0

    capture_all info "With emoji"
    assert_contains "$CAPTURED_OUTPUT" "ℹ️" "Emoji restored"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_9_function_management() {
    test_start "Function Management - Create Custom Function"

    # Create custom function
    stream_function "trace" --emoji " 🔍" --tag " [TRACE] -" --channel "debug" --exit -1

    # Enable it (since debug channel might be off)
    stream_function trace --enable

    capture_all trace "Trace message"

    assert_contains "$CAPTURED_OUTPUT" "[TRACE]" "Custom function has correct tag"
    assert_contains "$CAPTURED_OUTPUT" "🔍" "Custom function has correct emoji"
    assert_contains "$CAPTURED_OUTPUT" "Trace message" "Custom function message present"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_10_nop_functions() {
    test_start "NOP Functions (Disable/Enable)"

    # Disable warn function
    stream_function warn --disable

    capture_all warn "Should not appear"

    assert_equal "$CAPTURED_OUTPUT" "" "Disabled function produces no output"

    # Re-enable
    stream_function warn --enable

    capture_all warn "Should appear"
    assert_contains "$CAPTURED_OUTPUT" "Should appear" "Re-enabled function works"
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

    capture_all info "Combined test"

    # Should have NO date
    if [[ ! "$CAPTURED_OUTPUT" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        assert "true" "No date in combined mode"
    else
        assert "false" "No date in combined mode"
    fi

    # Should have time
    if [[ "$CAPTURED_OUTPUT" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        assert "true" "Time present in combined mode"
    else
        assert "false" "Time present in combined mode"
    fi

    # Should have no emoji
    if [[ "$CAPTURED_OUTPUT" =~ ℹ️ ]]; then
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

# --------------------------------------------------------------------------------------------------
test_14_special_characters() {
    test_start "Special Characters (%, ', \\, newlines in tags/emojis)"

    # Test % sign escaping in custom tag
    stream_function "test_percent" --emoji " % " --tag " [TEST%100] -" --channel "stderr" --exit -1
    capture_all test_percent "Percent test"
    
    assert_contains "$CAPTURED_OUTPUT" "Percent test" "Message with % in tag works"
    assert_contains "$CAPTURED_OUTPUT" "[TEST%100]" "Tag with % sign renders correctly"

    # Test single quote in tag
    stream_function "test_quote" --emoji " ' " --tag " [IT'S] -" --channel "stderr" --exit -1
    capture_all test_quote "Quote test"
    
    assert_contains "$CAPTURED_OUTPUT" "Quote test" "Message with ' in tag works"
    assert_contains "$CAPTURED_OUTPUT" "[IT'S]" "Tag with single quote renders correctly"

    # Test backslash in tag
    stream_function "test_backslash" --emoji " \\ " --tag " [PATH\\TEST] -" --channel "stderr" --exit -1
    capture_all test_backslash "Backslash test"
    
    assert_contains "$CAPTURED_OUTPUT" "Backslash test" "Message with \\ in tag works"
    assert_contains "$CAPTURED_OUTPUT" "[PATH" "Tag with backslash renders"

    # Test message with special chars (passed as argument, not embedded in format)
    capture_all info "Message with % and ' and \\"
    assert_contains "$CAPTURED_OUTPUT" "Message with % and ' and \\" "Special chars in message work"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_15_default_message() {
    test_start "Default Message Feature (no argument provided)"

    # Test default message with info
    capture_all info
    assert_contains "$CAPTURED_OUTPUT" "<No message>" "Default message shows '<No message>'"
    assert_contains "$CAPTURED_OUTPUT" "capture_all" "Default message shows caller (capture_all wrapper)"
    assert_contains "$CAPTURED_OUTPUT" "Test.sh" "Default message shows source file"
    
    # Test default message with warn
    capture_all warn
    assert_contains "$CAPTURED_OUTPUT" "<No message>" "warn default message works"
    assert_contains "$CAPTURED_OUTPUT" "capture_all" "warn shows caller function"
    
    # Test default message with error  
    capture_all error
    assert_contains "$CAPTURED_OUTPUT" "<No message>" "error default message works"
    assert_contains "$CAPTURED_OUTPUT" "#" "error shows line number marker"
    
    # Verify message IS provided when argument given
    capture_all info "Actual message"
    assert_contains "$CAPTURED_OUTPUT" "Actual message" "Provided message appears"
    assert "[[ \"$CAPTURED_OUTPUT\" != *'<No message>'* ]]" "No default when message provided"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_16_output_file_behavior() {
    test_start "output() File Behavior (plain console, formatted file)"

    local tmpfile
    tmpfile=$(mktemp)

    # Enable file output for stdout channel
    stream_set_channel stdout --file-path "$tmpfile" --file 1

    # Test output() - console is plain, file is formatted
    capture_all output "Test output message"
    
    # Console should be plain (no timestamp)
    assert_contains "$CAPTURED_OUTPUT" "Test output message" "output() console shows message"
    assert "[[ \"$CAPTURED_OUTPUT\" != *':'* ]]" "output() console has NO timestamp"
    
    # File should have timestamp (formatted)
    local file_content
    file_content=$(cat "$tmpfile")
    assert_contains "$file_content" "Test output message" "output() file contains message"
    
    # Check if file has timestamp pattern (YYYY-MM-DD HH:MM:SS)
    if [[ "$file_content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        printf '  ✓ output() file has timestamp (formatted)\n'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        printf '  ✗ FAILED: output() file missing timestamp\n'
        printf "    File content: '%s'\n" "$file_content"
    fi

    # Clear file path
    stream_set_channel stdout --file-path ""

    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
test_17_fd_management() {
    test_start "FD Management (validation, opening, cleanup)"

    # Test FD 1-2 are always available (no error)
    stream_function "test_fd1" --channel "stdout" --emoji "" --tag ""
    assert "[[ $? -eq 0 ]]" "FD 1 (stdout) is always available"
    
    # Test FD 3-9 are automatically opened
    # Temporarily change debug channel to use FD 5
    local original_debug_fd="${__STREAMS_CONFIG[CHANNEL::debug::FD]}"
    __STREAMS_CONFIG[CHANNEL::debug::FD]=5
    
    # Regenerate debug function (should open FD 5)
    stream_function "debug" --enable
    assert "[[ $? -eq 0 ]]" "FD 5 can be used"
    
    # Verify FD 5 is now tracked
    local found=0
    for fd in "${__STREAMS_OPENED_FDS[@]}"; do
        if [[ "$fd" -eq 5 ]]; then
            found=1
            break
        fi
    done
    assert "[[ $found -eq 1 ]]" "FD 5 is tracked in registry"
    
    # Restore debug channel FD
    __STREAMS_CONFIG[CHANNEL::debug::FD]="$original_debug_fd"
    
    # Test FD > 9 causes error
    __STREAMS_CONFIG[CHANNEL::debug::FD]=10
    stream_function "debug" --enable 2>/dev/null
    assert "[[ $? -ne 0 ]]" "FD 10 (out of range) causes error"
    
    # Restore debug channel FD again
    __STREAMS_CONFIG[CHANNEL::debug::FD]="$original_debug_fd"
    
    # Test stream_cleanup closes FDs
    local fds_before="${#__STREAMS_OPENED_FDS[@]}"
    stream_cleanup
    local fds_after="${#__STREAMS_OPENED_FDS[@]}"
    assert "[[ $fds_after -eq 0 ]]" "stream_cleanup clears FD registry"
    assert "[[ $fds_before -gt 0 ]]" "FD registry had entries before cleanup"
    
    # Re-initialize all functions with correct FDs
    __streams_defineFN_all
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# EXECUTE TESTS
# ==================================================================================================

main "$@"
