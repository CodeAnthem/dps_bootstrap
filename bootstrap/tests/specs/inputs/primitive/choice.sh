#!/usr/bin/env bash
# Choice validation tests

test_choice() {
    # Setup options context for choice validation
    INPUT_OPTIONS_CACHE["options"]="yes|no|auto"
    
    # Valid choices
    assert_valid "choice" "yes"
    assert_valid "choice" "no"
    assert_valid "choice" "auto"
    
    # Invalid choices
    assert_invalid "choice" "y"
    assert_invalid "choice" "n"
    assert_invalid "choice" "maybe"
    assert_invalid "choice" "invalid"
    
    # Clear context
    INPUT_OPTIONS_CACHE=()
}
