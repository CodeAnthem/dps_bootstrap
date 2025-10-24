# DPS Bootstrap Test Suite

## Overview

Automated test suite for input validators and configuration system.

## Structure

```
bootstrap/tests/
├── run.sh           # Test runner (auto-discovery)
├── specs/           # Test specifications
│   └── inputs/      # Input validator tests
│       ├── network/
│       ├── primitive/
│       ├── system/
│       └── disk/
└── README.md        # This file
```

## Running Tests

### Via Action System
```bash
./start.sh
# Select: 3) test
```

### Direct Execution
```bash
cd bootstrap
./tests/run.sh
```

## Writing Tests

### Test File Structure

Each input validator should have a corresponding test file:

```bash
# specs/inputs/category/input_name.sh
#!/usr/bin/env bash

test_input_name() {
    # Setup context if needed (e.g., for choice input)
    # INPUT_OPTIONS_CACHE["options"]="opt1|opt2|opt3"
    
    # Valid cases
    assert_valid "input_name" "valid_value_1"
    assert_valid "input_name" "valid_value_2"
    
    # Invalid cases
    assert_invalid "input_name" "invalid_value_1"
    assert_invalid "input_name" "invalid_value_2"
    
    # Cleanup context if set
    # INPUT_OPTIONS_CACHE=()
}
```

### Test Assertions

- **`assert_valid "input_name" "value"`** - Expects validation to pass
- **`assert_invalid "input_name" "value"`** - Expects validation to fail

## Test Philosophy

### What We Test

✅ **Validation Functions** - Test `validate_*` functions for each input type
✅ **Edge Cases** - Minimum/maximum values, special characters, boundary conditions
✅ **Error Conditions** - Invalid formats, out-of-range values

### What We Don't Test

❌ **Prompts** - Interactive prompting is tested manually  
❌ **Normalization** - Covered by integration tests  
❌ **Display Functions** - UI concerns, not critical logic

### Why This Approach?

1. **Low Maintenance** - Tests validate core logic, not UI/formatting
2. **Fast Execution** - No interactive prompts, pure validation
3. **Input-Focused** - Each input file has ONE test function
4. **Auto-Discovery** - Just drop in `test_*.sh` files

### Context Setup for Complex Inputs

Some inputs (like `choice`) require context:

```bash
test_choice() {
    # Setup options that choice validator will read
    INPUT_OPTIONS_CACHE["options"]="yes|no|auto"
    
    assert_valid "choice" "yes"
    assert_invalid "choice" "maybe"
    
    # Clear context
    INPUT_OPTIONS_CACHE=()
}
```

## Auto-Discovery

The test runner automatically:
1. Sources all `.sh` files in `specs/inputs/*/`
2. Finds all functions starting with `test_`
3. Runs them and reports results

No manual registration needed!

## Test Guidelines

1. **One test function per input** - `test_ip()`, `test_hostname()`, etc.
2. **Focus on validation** - Test the `validate_*` function behavior
3. **Use clear values** - Make it obvious what's being tested
4. **Clean up context** - Clear any INPUT_OPTIONS_CACHE you set
5. **Keep it simple** - Tests should be easy to read and maintain

## Future Enhancements

- Integration tests for full configuration workflows
- Performance benchmarks for validators
- Coverage reporting for edge cases
