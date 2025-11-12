#!/usr/bin/env bash
# ==================================================================================================
# Trap Multiplexer - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-10 | Modified: 2025-11-12
# Description:   Comprehensive test suite for Trap Multiplexer
# Feature:       Tests for named handlers, priorities, limits, exit policies, and edge cases
# ==================================================================================================
# shellcheck disable=SC2064  # Intentional variable expansion in trap commands
# shellcheck disable=SC1091  # Source: Source Not following
# shellcheck disable=SC1090  # Source: Can't follow non-constant source

# ==================================================================================================
# EXECUTION GUARD
# ==================================================================================================

# Prevent sourcing - this file must be executed
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    printf 'Error: This test script must be executed, not sourced\n -> File: %s\n' "${0}" >&2
    return 1
fi

# ==================================================================================================
# PATH RESOLUTION & FEATURE LOADING
# ==================================================================================================

# Get script directory (resolve symlinks)
SCRIPT_DIR="${BASH_SOURCE[0]}"
while [[ -h "$SCRIPT_DIR" ]]; do
    SCRIPT_DIR="$(readlink "$SCRIPT_DIR")"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_DIR")" && pwd)"

# Get folder name and construct feature file path
FOLDER_NAME="$(basename "$SCRIPT_DIR")"
FEATURE_FILE="${SCRIPT_DIR}/${FOLDER_NAME}.sh"

# Verify feature file exists
if [[ ! -f "$FEATURE_FILE" ]]; then
    printf 'Error: Feature file not found: %s\n' "$FEATURE_FILE" >&2
    exit 1
fi

# Source the feature file
source "$FEATURE_FILE" || {
    printf 'Error: Failed to source feature file: %s\n' "$FEATURE_FILE" >&2
    exit 1
}

# ==================================================================================================
# MAIN TEST ORCHESTRATOR
# ==================================================================================================

main() {
    # Print test suite header
    printf '╔════════════════════════════════════════════════════════════════════════════════╗\n'
    printf '║                      TRAP MULTIPLEXER - TEST SUITE                             ║\n'
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'
    
    # Run all tests
    test_1_named_handler
    test_2_anonymous_handler
    test_3_priority_order
    test_4_oneshot_handler
    test_5_nshot_handler
    test_6_policy_force_with_exit
    test_7_policy_force_no_exit
    test_8_policy_once
    test_9_policy_never
    test_10_unregister_handler
    test_11_suspend_resume
    test_12_priority_fifo
    test_13_handler_info
    test_14_has_handlers
    test_15_clear_handlers
    test_16_negative_priority
    test_17_last_name_variable
    test_18_eval_disabled
    
    # Print summary
    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Test 1: Named Handler Registration
test_1_named_handler() {
    test_start "Named Handler Registration"
    
    trap_clear SIGUSR1
    trap_named "test_handler" 'echo "test"' SIGUSR1
    
    local count
    count=$(trap_count SIGUSR1)
    assert_equal "$count" "1" "Handler registered"
    
    local list
    list=$(trap_list SIGUSR1)
    assert_contains "$list" "test_handler" "Handler name in list"
    
    local info
    info=$(trap_handler_info "SIGUSR1:test_handler")
    assert_contains "$info" "code=echo \"test\"" "Handler code stored"
    assert_contains "$info" "priority=0" "Default priority is 0"
    assert_contains "$info" "limit=0" "Default limit is 0 (unlimited)"
    assert_contains "$info" "count=0" "Execution count starts at 0"
    
    trap_clear SIGUSR1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 2: Anonymous Handler Auto-Naming
test_2_anonymous_handler() {
    test_start "Anonymous Handler Auto-Naming"
    
    trap_clear SIGUSR1
    trap 'echo "handler1"' SIGUSR1
    trap 'echo "handler2"' SIGUSR1
    
    local count
    count=$(trap_count SIGUSR1)
    assert_equal "$count" "2" "Two anonymous handlers registered"
    
    local list
    list=$(trap_list SIGUSR1)
    assert_contains "$list" "anonymous_" "Auto-generated names contain 'anonymous_'"
    
    trap_clear SIGUSR1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 3: Priority Execution Order
test_3_priority_order() {
    test_start "Priority Execution Order"
    
    local tmpfile script
    tmpfile=$(mktemp)
    script=$(mktemp)
    
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"

tmpfile="$2"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never

trap_named "low" "echo 'low' >> '$tmpfile'" SIGUSR1
trap_named "high" "echo 'high' >> '$tmpfile'" SIGUSR1
trap_named "medium" "echo 'medium' >> '$tmpfile'" SIGUSR1

trap_policy_priority_set "SIGUSR1:low" 0
trap_policy_priority_set "SIGUSR1:high" 10
trap_policy_priority_set "SIGUSR1:medium" 5

kill -SIGUSR1 $$
sleep 0.3
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE" "$tmpfile"
    
    local first second third
    first=$(sed -n '1p' "$tmpfile" 2>/dev/null)
    second=$(sed -n '2p' "$tmpfile" 2>/dev/null)
    third=$(sed -n '3p' "$tmpfile" 2>/dev/null)
    
    assert_equal "$first" "high" "High priority executed first"
    assert_equal "$second" "medium" "Medium priority executed second"
    assert_equal "$third" "low" "Low priority executed last"
    
    rm -f "$tmpfile" "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 4: One-Shot Handler
test_4_oneshot_handler() {
    test_start "One-Shot Handler (Auto-Remove After 1 Execution)"
    
    local tmpfile script
    tmpfile=$(mktemp)
    script=$(mktemp)
    
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"

tmpfile="$2"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never

trap_named "oneshot" "echo 'executed' >> '$tmpfile'" SIGUSR1
trap_policy_limit_set "SIGUSR1:oneshot" 1

kill -SIGUSR1 $$
sleep 0.1
kill -SIGUSR1 $$
sleep 0.1
kill -SIGUSR1 $$
sleep 0.1
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE" "$tmpfile" 2>/dev/null
    
    local line_count
    line_count=$(wc -l < "$tmpfile" 2>/dev/null || echo 0)
    assert_equal "$line_count" "1" "Handler executed exactly once"
    
    rm -f "$tmpfile" "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 5: N-Shot Handler
test_5_nshot_handler() {
    test_start "N-Shot Handler (Auto-Remove After N Executions)"
    
    local tmpfile script
    tmpfile=$(mktemp)
    script=$(mktemp)
    
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"

tmpfile="$2"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never

trap_named "threeshot" "echo 'executed' >> '$tmpfile'" SIGUSR1
trap_policy_limit_set "SIGUSR1:threeshot" 3

for i in {1..5}; do
    kill -SIGUSR1 $$
    sleep 0.1
done
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE" "$tmpfile" 2>/dev/null
    
    local line_count
    line_count=$(wc -l < "$tmpfile" 2>/dev/null || echo 0)
    assert_equal "$line_count" "3" "Handler executed exactly 3 times"
    
    rm -f "$tmpfile" "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 6: Exit Policy - Force (with exit code)
test_6_policy_force_with_exit() {
    test_start "Exit Policy 'force' - Use First Exit Code"
    
    local script
    script=$(mktemp)
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 force
trap_named "handler1" 'exit 42' SIGUSR1
trap_named "handler2" 'echo "handler2"' SIGUSR1
kill -SIGUSR1 $$
echo "This should not print"
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE"
    local exit_code=$?
    
    assert_equal "$exit_code" "42" "Exited with first exit code (42)"
    
    rm -f "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 7: Exit Policy - Force (without exit code)
test_7_policy_force_no_exit() {
    test_start "Exit Policy 'force' - Default to 0 if No Exit Called"
    
    local script
    script=$(mktemp)
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 force
trap_named "handler1" 'echo "handler1"' SIGUSR1
trap_named "handler2" 'echo "handler2"' SIGUSR1
kill -SIGUSR1 $$
echo "This should not print"
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE" 2>/dev/null
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Exited with code 0 (no exit called)"
    
    rm -f "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 8: Exit Policy - Once (last exit code)
test_8_policy_once() {
    test_start "Exit Policy 'once' - Use Last Exit Code"
    
    local script
    script=$(mktemp)
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 once
trap_named "handler1" 'exit 10' SIGUSR1
trap_named "handler2" 'exit 20' SIGUSR1
trap_named "handler3" 'exit 30' SIGUSR1
kill -SIGUSR1 $$
echo "This should not print"
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE"
    local exit_code=$?
    
    assert_equal "$exit_code" "30" "Exited with last exit code (30)"
    
    rm -f "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 9: Exit Policy - Never
test_9_policy_never() {
    test_start "Exit Policy 'never' - Ignore All Exit Requests"
    
    local script
    script=$(mktemp)
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never
trap_named "handler1" 'exit 10' SIGUSR1
trap_named "handler2" 'exit 20' SIGUSR1
kill -SIGUSR1 $$
echo "continued"
exit 77
SCRIPT_END
    
    local output
    output=$(bash "$script" "$FEATURE_FILE" 2>/dev/null)
    local exit_code=$?
    
    assert_contains "$output" "continued" "Execution continued after signal"
    assert_equal "$exit_code" "77" "Exited normally (not from handlers)"
    
    rm -f "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 10: Unregister Handler by Name
test_10_unregister_handler() {
    test_start "Unregister Handler by Name"
    
    trap_clear SIGUSR1
    trap_named "handler1" 'echo "h1"' SIGUSR1
    trap_named "handler2" 'echo "h2"' SIGUSR1
    trap_named "handler3" 'echo "h3"' SIGUSR1
    
    local count
    count=$(trap_count SIGUSR1)
    assert_equal "$count" "3" "Three handlers registered"
    
    trap_unregister SIGUSR1 "handler2"
    count=$(trap_count SIGUSR1)
    assert_equal "$count" "2" "One handler removed"
    
    local list
    list=$(trap_list SIGUSR1)
    assert_not_contains "$list" "handler2" "Removed handler not in list"
    assert_contains "$list" "handler1" "Other handler still in list"
    assert_contains "$list" "handler3" "Other handler still in list"
    
    trap_clear SIGUSR1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 11: Suspend and Resume Handlers
test_11_suspend_resume() {
    test_start "Suspend and Resume Handlers"
    
    trap_clear SIGUSR1
    trap_suspend SIGUSR1
    
    assert "trap_is_suspended SIGUSR1" "Handlers suspended"
    
    trap_resume SIGUSR1
    assert "! trap_is_suspended SIGUSR1" "Handlers resumed"
    
    trap_clear SIGUSR1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 12: Priority Ties Maintain FIFO Order
test_12_priority_fifo() {
    test_start "Priority Ties Maintain FIFO Order"
    
    local tmpfile script
    tmpfile=$(mktemp)
    script=$(mktemp)
    
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"

tmpfile="$2"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never

trap_named "first" "echo 'F' >> '$tmpfile'" SIGUSR1
trap_named "second" "echo 'S' >> '$tmpfile'" SIGUSR1
trap_named "third" "echo 'T' >> '$tmpfile'" SIGUSR1

kill -SIGUSR1 $$
sleep 0.2
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE" "$tmpfile"
    
    local first second third
    first=$(sed -n '1p' "$tmpfile" 2>/dev/null)
    second=$(sed -n '2p' "$tmpfile" 2>/dev/null)
    third=$(sed -n '3p' "$tmpfile" 2>/dev/null)
    
    assert_equal "$first" "F" "First registered executed first"
    assert_equal "$second" "S" "Second registered executed second"
    assert_equal "$third" "T" "Third registered executed third"
    
    rm -f "$tmpfile" "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 13: Query Handler Information
test_13_handler_info() {
    test_start "Query Handler Information"
    
    trap_clear SIGUSR1
    trap_named "info_test" 'echo "code"' SIGUSR1
    trap_policy_priority_set "SIGUSR1:info_test" 5
    trap_policy_limit_set "SIGUSR1:info_test" 3
    
    local info
    info=$(trap_handler_info "SIGUSR1:info_test")
    
    assert_contains "$info" "code=echo \"code\"" "Code correct"
    assert_contains "$info" "priority=5" "Priority correct"
    assert_contains "$info" "limit=3" "Limit correct"
    assert_contains "$info" "count=0" "Count starts at 0"
    
    trap_clear SIGUSR1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 14: Check If Signal Has Handlers
test_14_has_handlers() {
    test_start "Check If Signal Has Handlers"
    
    trap_clear SIGUSR1
    assert "! trap_has SIGUSR1" "No handlers initially"
    
    trap_named "test" 'echo "test"' SIGUSR1
    assert "trap_has SIGUSR1" "Handler detected after registration"
    
    trap_clear SIGUSR1
    assert "! trap_has SIGUSR1" "No handlers after clear"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 15: Clear All Handlers for Signal
test_15_clear_handlers() {
    test_start "Clear All Handlers for Signal"
    
    trap_clear SIGUSR1
    trap_named "h1" 'echo "1"' SIGUSR1
    trap_named "h2" 'echo "2"' SIGUSR1
    trap_named "h3" 'echo "3"' SIGUSR1
    
    local count
    count=$(trap_count SIGUSR1)
    assert_equal "$count" "3" "Three handlers registered"
    
    trap_clear SIGUSR1
    count=$(trap_count SIGUSR1)
    assert_equal "$count" "0" "All handlers cleared"
    
    assert "! trap_has SIGUSR1" "No handlers after clear"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 16: Negative Priority Values
test_16_negative_priority() {
    test_start "Negative Priority Values"
    
    local tmpfile script
    tmpfile=$(mktemp)
    script=$(mktemp)
    
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"

tmpfile="$2"
trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never

trap_named "positive" "echo 'P' >> '$tmpfile'" SIGUSR1
trap_named "zero" "echo 'Z' >> '$tmpfile'" SIGUSR1
trap_named "negative" "echo 'N' >> '$tmpfile'" SIGUSR1

trap_policy_priority_set "SIGUSR1:positive" 10
trap_policy_priority_set "SIGUSR1:zero" 0
trap_policy_priority_set "SIGUSR1:negative" -5

kill -SIGUSR1 $$
sleep 0.2
SCRIPT_END
    
    bash "$script" "$FEATURE_FILE" "$tmpfile"
    
    local first second third
    first=$(sed -n '1p' "$tmpfile" 2>/dev/null)
    second=$(sed -n '2p' "$tmpfile" 2>/dev/null)
    third=$(sed -n '3p' "$tmpfile" 2>/dev/null)
    
    assert_equal "$first" "P" "Positive priority first"
    assert_equal "$second" "Z" "Zero priority second"
    assert_equal "$third" "N" "Negative priority last"
    
    rm -f "$tmpfile" "$script"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 17: TRAP_LAST_NAME Variable
test_17_last_name_variable() {
    test_start "TRAP_LAST_NAME Tracking"
    
    trap_clear SIGUSR1
    
    # Named handler
    trap_named "my_handler" 'echo "test"' SIGUSR1
    assert_equal "$TRAP_LAST_NAME" "SIGUSR1:my_handler" "TRAP_LAST_NAME set for named handler"
    
    # Anonymous handler
    trap 'echo "anon"' SIGUSR1
    assert_contains "$TRAP_LAST_NAME" "SIGUSR1:anonymous_" "TRAP_LAST_NAME set for anonymous handler"
    
    # Can use TRAP_LAST_NAME to configure anonymous trap
    trap_policy_priority_set "$TRAP_LAST_NAME" 10
    local priority
    priority=$(trap_policy_priority_get "$TRAP_LAST_NAME")
    assert_equal "$priority" "10" "Can configure using TRAP_LAST_NAME"
    
    trap_clear SIGUSR1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 18: Eval Disabled Safety
test_18_eval_disabled() {
    test_start "Eval Disabled Safety Feature"
    
    local script
    script=$(mktemp)
    cat > "$script" << 'SCRIPT_END'
#!/usr/bin/env bash
source "$1"

tmpfile="$2"

trap_clear SIGUSR1
trap_policy_exit_set SIGUSR1 never

# Define a function
test_func() { echo "func" >> "$tmpfile"; }

# Register function handler
trap_named "func_handler" test_func SIGUSR1

# Register inline handler
trap_named "inline_handler" "echo 'inline' >> '$tmpfile'" SIGUSR1

# Disable eval
trap_disable_eval

# Trigger signal
kill -SIGUSR1 $$
sleep 0.2
SCRIPT_END
    
    local tmpfile
    tmpfile=$(mktemp)
    bash "$script" "$FEATURE_FILE" "$tmpfile" 2>/dev/null
    
    local content
    content=$(cat "$tmpfile" 2>/dev/null)
    
    assert_contains "$content" "func" "Function handler executed"
    assert_not_contains "$content" "inline" "Inline handler blocked (eval disabled)"
    
    rm -f "$tmpfile" "$script"
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# TEST FRAMEWORK
# ==================================================================================================

declare -g TEST_COUNT=0
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g CURRENT_TEST=""

test_start() {
    CURRENT_TEST="$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test #$TEST_COUNT: $CURRENT_TEST"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
# --------------------------------------------------------------------------------------------------

assert() {
    local condition="$1"
    local description="$2"
    
    if eval "$condition"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo "  ✓ $description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        echo "  ✗ FAILED: $description"
        echo "    Condition: $condition"
    fi
}
# --------------------------------------------------------------------------------------------------

assert_equal() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo "  ✓ $description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        echo "  ✗ FAILED: $description"
        echo "    Expected: '$expected'"
        echo "    Got:      '$actual'"
    fi
}
# --------------------------------------------------------------------------------------------------

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo "  ✓ $description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        echo "  ✗ FAILED: $description"
        echo "    Expected to contain: '$needle'"
        echo "    In: '$haystack'"
    fi
}
# --------------------------------------------------------------------------------------------------

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo "  ✓ $description"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        echo "  ✗ FAILED: $description"
        echo "    Expected NOT to contain: '$needle'"
        echo "    In: '$haystack'"
    fi
}
# --------------------------------------------------------------------------------------------------

test_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              TEST SUMMARY                                      ║"
    echo "╠════════════════════════════════════════════════════════════════════════════════╣"
    printf "║  Total Tests:    %-58s  ║\n" "$TEST_COUNT"
    printf "║  Total Asserts:  %-58s  ║\n" "$((TEST_PASSED + TEST_FAILED))"
    printf "║  ✓ Passed:       %-58s  ║\n" "$TEST_PASSED"
    printf "║  ✗ Failed:       %-58s  ║\n" "$TEST_FAILED"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        echo ""
        echo "✅ ALL TESTS PASSED!"
        return 0
    else
        echo ""
        echo "❌ SOME TESTS FAILED"
        return 1
    fi
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# EXECUTE TESTS
# ==================================================================================================

main "$@"
