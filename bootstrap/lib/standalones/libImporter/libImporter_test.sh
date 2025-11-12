#!/usr/bin/env bash
# ==================================================================================================
# Library Importer - Test Suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-12 | Modified: 2025-11-12
# Description:   Comprehensive test suite for Library Importer
# Feature:       Tests for file/directory import, validation, named import, and error handling
# ==================================================================================================
# shellcheck disable=SC1090  # Can't follow non-constant source
# shellcheck disable=SC1091  # Source not following

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
    printf '║                       LIBRARY IMPORTER - TEST SUITE                            ║\n'
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'
    
    # Run all tests
    test_1_import_valid_file
    test_2_import_nonexistent_file
    test_3_import_file_with_syntax_error
    test_4_import_dir_non_recursive
    test_5_import_dir_recursive
    test_6_import_dir_skip_underscore_files
    test_7_import_named_folder
    test_8_import_named_missing_file
    test_9_validate_only
    test_10_multiple_errors
    test_11_import_dir_invalid_recursive_param
    
    # Print summary
    test_summary
}

# ==================================================================================================
# TEST CASES
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Test 1: Import Valid File
test_1_import_valid_file() {
    test_start "Import Valid File"
    
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile" << 'EOF'
#!/usr/bin/env bash
test_var_1="success"
EOF
    
    import_file "$tmpfile"
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Import succeeded"
    assert_equal "$test_var_1" "success" "Variable set correctly"
    
    rm -f "$tmpfile"
    unset test_var_1
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 2: Import Nonexistent File
test_2_import_nonexistent_file() {
    test_start "Import Nonexistent File"
    
    local output
    output=$(import_file "/nonexistent/file.sh" 2>&1)
    local exit_code=$?
    
    assert_equal "$exit_code" "1" "Import failed with exit code 1"
    assert_contains "$output" "File not found" "Error message shown"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 3: Import File with Syntax Error
test_3_import_file_with_syntax_error() {
    test_start "Import File with Syntax Error"
    
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile" << 'EOF'
#!/usr/bin/env bash
if [[ true ]]; then
    echo "missing fi"
EOF
    
    local output
    output=$(import_file "$tmpfile" 2>&1)
    local exit_code=$?
    
    assert_equal "$exit_code" "1" "Import failed"
    assert_contains "$output" "Validation Error" "Validation error reported"
    
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 4: Import Directory (Non-Recursive)
test_4_import_dir_non_recursive() {
    test_start "Import Directory (Non-Recursive)"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create test files
    echo 'test_var_4a="loaded_a"' > "$tmpdir/file_a.sh"
    echo 'test_var_4b="loaded_b"' > "$tmpdir/file_b.sh"
    
    # Create subdirectory (should be ignored in non-recursive mode)
    mkdir -p "$tmpdir/subdir"
    echo 'test_var_4c="loaded_c"' > "$tmpdir/subdir/file_c.sh"
    
    import_dir "$tmpdir" false
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Import succeeded"
    assert_equal "$test_var_4a" "loaded_a" "File A loaded"
    assert_equal "$test_var_4b" "loaded_b" "File B loaded"
    assert_equal "${test_var_4c:-unset}" "unset" "Subdirectory file NOT loaded (non-recursive)"
    
    rm -rf "$tmpdir"
    unset test_var_4a test_var_4b test_var_4c
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 5: Import Directory (Recursive)
test_5_import_dir_recursive() {
    test_start "Import Directory (Recursive)"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create test files
    echo 'test_var_5a="loaded_a"' > "$tmpdir/file_a.sh"
    
    # Create subdirectory
    mkdir -p "$tmpdir/subdir"
    echo 'test_var_5b="loaded_b"' > "$tmpdir/subdir/file_b.sh"
    
    # Create nested subdirectory
    mkdir -p "$tmpdir/subdir/nested"
    echo 'test_var_5c="loaded_c"' > "$tmpdir/subdir/nested/file_c.sh"
    
    import_dir "$tmpdir" true
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Import succeeded"
    assert_equal "$test_var_5a" "loaded_a" "Root file loaded"
    assert_equal "$test_var_5b" "loaded_b" "Subdirectory file loaded"
    assert_equal "$test_var_5c" "loaded_c" "Nested file loaded (recursive)"
    
    rm -rf "$tmpdir"
    unset test_var_5a test_var_5b test_var_5c
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 6: Import Directory Skips Underscore-Prefixed Files
test_6_import_dir_skip_underscore_files() {
    test_start "Import Directory Skips Underscore-Prefixed Files"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create regular file
    echo 'test_var_6a="loaded"' > "$tmpdir/regular.sh"
    
    # Create underscore-prefixed file (should be skipped)
    echo 'test_var_6b="should_not_load"' > "$tmpdir/_internal.sh"
    
    import_dir "$tmpdir" false
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Import succeeded"
    assert_equal "$test_var_6a" "loaded" "Regular file loaded"
    assert_equal "${test_var_6b:-unset}" "unset" "Underscore-prefixed file skipped"
    
    rm -rf "$tmpdir"
    unset test_var_6a test_var_6b
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 7: Import Named Folder
test_7_import_named_folder() {
    test_start "Import Named Folder"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create folder with matching name
    local module_dir="$tmpdir/mymodule"
    mkdir -p "$module_dir"
    echo 'test_var_7="named_module_loaded"' > "$module_dir/mymodule.sh"
    
    import_named "$module_dir"
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Named import succeeded"
    assert_equal "$test_var_7" "named_module_loaded" "Named module loaded"
    
    rm -rf "$tmpdir"
    unset test_var_7
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 8: Import Named with Missing File
test_8_import_named_missing_file() {
    test_start "Import Named with Missing File"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create folder WITHOUT matching file
    local module_dir="$tmpdir/mymodule"
    mkdir -p "$module_dir"
    # No mymodule.sh file created
    
    local output
    output=$(import_named "$module_dir" 2>&1)
    local exit_code=$?
    
    assert_equal "$exit_code" "1" "Named import failed"
    assert_contains "$output" "Named file not found" "Error message shown"
    
    rm -rf "$tmpdir"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 9: Validate Only (No Source)
test_9_validate_only() {
    test_start "Validate Only (No Source)"
    
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile" << 'EOF'
#!/usr/bin/env bash
test_var_9="should_not_be_set"
EOF
    
    import_validate "$tmpfile"
    local exit_code=$?
    
    assert_equal "$exit_code" "0" "Validation succeeded"
    assert_equal "${test_var_9:-unset}" "unset" "Variable NOT set (validation only)"
    
    rm -f "$tmpfile"
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 10: Multiple Errors Accumulated
test_10_multiple_errors() {
    test_start "Multiple Errors Accumulated"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create valid file
    echo 'test_var_10a="ok"' > "$tmpdir/valid.sh"
    
    # Create file with syntax error
    cat > "$tmpdir/invalid.sh" << 'EOF'
#!/usr/bin/env bash
if [[ true ]]; then
    # Missing fi
EOF
    
    local output
    output=$(import_dir "$tmpdir" false 2>&1)
    local exit_code=$?
    
    assert_equal "$exit_code" "1" "Import failed due to errors"
    assert_contains "$output" "Validation Error" "Error reported"
    assert_equal "$test_var_10a" "ok" "Valid file still loaded before error"
    
    rm -rf "$tmpdir"
    unset test_var_10a
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Test 11: Import Directory with Invalid Recursive Parameter
test_11_import_dir_invalid_recursive_param() {
    test_start "Import Directory with Invalid Recursive Parameter"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    local output
    output=$(import_dir "$tmpdir" "invalid" 2>&1)
    local exit_code=$?
    
    assert_equal "$exit_code" "1" "Import failed"
    assert_contains "$output" "Invalid recursive parameter" "Error message shown"
    
    rm -rf "$tmpdir"
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# TEST FRAMEWORK
# ==================================================================================================

declare -g TEST_COUNT=0
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g CURRENT_TEST=""

# --------------------------------------------------------------------------------------------------
# Start a new test
# Usage: test_start <test_name>
test_start() {
    CURRENT_TEST="$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    printf '\n'
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    printf 'Test #%d: %s\n' "$TEST_COUNT" "$CURRENT_TEST"
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Assert a condition is true
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
# Assert two values are equal
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
# Assert haystack contains needle
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
    printf '\n'
    printf '╔════════════════════════════════════════════════════════════════════════════════╗\n'
    printf '║                              TEST SUMMARY                                      ║\n'
    printf '╠════════════════════════════════════════════════════════════════════════════════╣\n'
    printf '║  Total Tests:    %-58s  ║\n' "$TEST_COUNT"
    printf '║  Total Asserts:  %-58s  ║\n' "$((TEST_PASSED + TEST_FAILED))"
    printf '║  ✓ Passed:       %-58s  ║\n' "$TEST_PASSED"
    printf '║  ✗ Failed:       %-58s  ║\n' "$TEST_FAILED"
    printf '╚════════════════════════════════════════════════════════════════════════════════╝\n'
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        printf '\n'
        printf '✅ ALL TESTS PASSED!\n'
        return 0
    else
        printf '\n'
        printf '❌ SOME TESTS FAILED\n'
        return 1
    fi
}
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# EXECUTE TESTS
# ==================================================================================================

main "$@"
