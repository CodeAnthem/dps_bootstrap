#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test framework (read-only — does not modify the system)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Shared assertions and suite runner for NDS self-tests
# ==================================================================================================

declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SUITE=""

assert_valid() {
    local input_name="$1"
    local value="$2"

    if "validate_${input_name}" "$value" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ valid: $value"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ expected valid: $value"
    fi
}

assert_invalid() {
    local input_name="$1"
    local value="$2"

    if ! "validate_${input_name}" "$value" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ invalid: $value"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ expected invalid: $value"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="${3:-output}"

    if [[ "$haystack" == *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ${label} contains: ${needle}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ${label} missing: ${needle}"
    fi
}

run_named_suite() {
    local suite_name="$1"
    shift
    local suite_func="$1"

    TEST_SUITE="$suite_name"
    section_header "Suite: $suite_name"
    "$suite_func"
}

print_test_summary() {
    console ""
    section_header "Test summary"
    console "  Passed: $TEST_PASSED"
    console "  Failed: $TEST_FAILED"
    console "  Total:  $((TEST_PASSED + TEST_FAILED))"

    if [[ $TEST_FAILED -eq 0 ]]; then
        success "All tests passed"
        return 0
    fi
    error "$TEST_FAILED test(s) failed"
    return 1
}
