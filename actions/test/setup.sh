#!/usr/bin/env bash
# ==================================================================================================
# Metadata:      Test Action
# Description:   Run test suite for inputs and configuration system
# ==================================================================================================

# Get action root directory
ACTION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ACTION_ROOT

# =============================================================================
# TEST FRAMEWORK
# =============================================================================

# Test state
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_CURRENT=""

# Assert helpers
assert_valid() {
    local input_name="$1"
    local value="$2"
    
    if "validate_${input_name}" "$value" 2>/dev/null; then
        ((TEST_PASSED++))
        console "  ✓ Valid: $value"
    else
        ((TEST_FAILED++))
        console "  ✗ Expected valid but got invalid: $value"
    fi
}

assert_invalid() {
    local input_name="$1"
    local value="$2"
    
    if ! "validate_${input_name}" "$value" 2>/dev/null; then
        ((TEST_PASSED++))
        console "  ✓ Invalid: $value"
    else
        ((TEST_FAILED++))
        console "  ✗ Expected invalid but got valid: $value"
    fi
}

# Test runner
run_test() {
    local test_name="$1"
    
    TEST_CURRENT="$test_name"
    console ""
    console "Testing: $test_name"
    
    "$test_name"
}

# Test discovery and execution
run_all_tests() {
    local test_dir="$ACTION_ROOT/specs"
    
    section_title "Running Test Suite"
    
    # Source all test files
    for test_file in "$test_dir"/inputs/**/*.sh; do
        [[ -f "$test_file" ]] || continue
        # shellcheck disable=SC1090
        source "$test_file"
    done
    
    # Run all test_* functions
    local test_functions
    mapfile -t test_functions < <(declare -F | awk '{print $3}' | grep '^test_')
    
    for test_func in "${test_functions[@]}"; do
        run_test "$test_func"
    done
    
    # Summary
    console ""
    section_title "Test Summary"
    console "  Passed: $TEST_PASSED"
    console "  Failed: $TEST_FAILED"
    console "  Total:  $((TEST_PASSED + TEST_FAILED))"
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        success "All tests passed!"
        return 0
    else
        error "$TEST_FAILED test(s) failed"
        return 1
    fi
}

# =============================================================================
# SETUP FUNCTION (Required by action system)
# =============================================================================
setup() {
    run_all_tests
}
