# Test Action

## Purpose
Automated test suite for DPS Bootstrap validation functions and components.

## Activation
This action is **only available when `DPS_TEST=true`**.

```bash
export DPS_TEST=true
bash start.sh
```

## What It Tests

### Validation Functions
- **IP Address**: Valid/invalid IPv4 addresses
- **Hostname**: Valid/invalid hostname formats
- **Network Mask**: CIDR notation and dotted decimal
- **Port Numbers**: Valid port ranges (1-65535)
- **Timezone**: Format validation and examples
- **Username**: Linux username rules
- **URL**: Protocol validation (http, https, git, ssh)
- **Path**: Absolute and relative path formats

### CIDR Conversion
- Tests CIDR to netmask conversion (e.g., /24 → 255.255.255.0)

## Output Format
```
Running validation function tests...

Testing IP Address Validation:
  ✅ PASS: Valid IP: 192.168.1.1
  ✅ PASS: Valid IP: 10.0.0.1
  ❌ FAIL: Invalid IP: 256.1.1.1

Test Summary:
  ✅ Passed: 45
  ❌ Failed: 0
  📊 Total:  45
```

## Adding New Tests
Add test functions following the pattern:
```bash
test_my_feature() {
    console ""
    console "Testing My Feature:"
    
    assert_true "Description" "command_to_test 'input'"
    assert_false "Should fail" "command_to_test 'bad_input'"
}
```

Then call it in `setup()` function.

## Continuous Integration
This test suite can be integrated into CI/CD pipelines to validate changes before deployment.
