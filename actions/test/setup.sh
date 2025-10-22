#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Test Action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Test action for validation functions and system components
# Feature:       Only enabled when DPS_TEST=true - validates all input validators
# Author:        DPS Project
# ==================================================================================================

set -euo pipefail

# =============================================================================
# ACTION METADATA
# =============================================================================
# Description: Test suite for validation functions
# This action only runs when DPS_TEST=true

# =============================================================================
# TEST HELPERS
# =============================================================================
test_passed=0
test_failed=0

assert_true() {
    local description="$1"
    local command="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        ((test_passed++))
        console "  ✅ PASS: $description"
        return 0
    else
        ((test_failed++))
        console "  ❌ FAIL: $description"
        return 1
    fi
}

assert_false() {
    local description="$1"
    local command="$2"
    
    if ! eval "$command" >/dev/null 2>&1; then
        ((test_passed++))
        console "  ✅ PASS: $description"
        return 0
    else
        ((test_failed++))
        console "  ❌ FAIL: $description"
        return 1
    fi
}

# =============================================================================
# VALIDATION TESTS
# =============================================================================

test_ip_validation() {
    console "Testing IP Address Validation:"
    
    # Valid IPs
    assert_true "Valid IP: 192.168.1.1" "validate_ip '192.168.1.1'"
    assert_true "Valid IP: 10.0.0.1" "validate_ip '10.0.0.1'"
    assert_true "Valid IP: 172.16.0.1" "validate_ip '172.16.0.1'"
    assert_true "Valid IP: 0.0.0.0" "validate_ip '0.0.0.0'"
    assert_true "Valid IP: 255.255.255.255" "validate_ip '255.255.255.255'"
    
    # Invalid IPs
    assert_false "Invalid IP: 256.1.1.1" "validate_ip '256.1.1.1'"
    assert_false "Invalid IP: 192.168.1" "validate_ip '192.168.1'"
    assert_false "Invalid IP: 192.168.1.1.1" "validate_ip '192.168.1.1.1'"
    assert_false "Invalid IP: abc.def.ghi.jkl" "validate_ip 'abc.def.ghi.jkl'"
    assert_false "Invalid IP: empty" "validate_ip ''"
}

test_hostname_validation() {
    console "Testing Hostname Validation:"
    
    # Valid hostnames
    assert_true "Valid hostname: server01" "validate_hostname 'server01'"
    assert_true "Valid hostname: my-server" "validate_hostname 'my-server'"
    assert_true "Valid hostname: web-server-01" "validate_hostname 'web-server-01'"
    assert_true "Valid hostname: a" "validate_hostname 'a'"
    
    # Invalid hostnames
    assert_false "Invalid hostname: -server" "validate_hostname '-server'"
    assert_false "Invalid hostname: server-" "validate_hostname 'server-'"
    assert_false "Invalid hostname: server_01" "validate_hostname 'server_01'"
    assert_false "Invalid hostname: empty" "validate_hostname ''"
}

test_netmask_validation() {
    console "Testing Network Mask Validation:"
    
    # Valid CIDR notation
    assert_true "Valid CIDR: 24" "validate_netmask '24'"
    assert_true "Valid CIDR: 16" "validate_netmask '16'"
    assert_true "Valid CIDR: 32" "validate_netmask '32'"
    assert_true "Valid CIDR: 0" "validate_netmask '0'"
    
    # Valid dotted decimal
    assert_true "Valid mask: 255.255.255.0" "validate_netmask '255.255.255.0'"
    assert_true "Valid mask: 255.255.0.0" "validate_netmask '255.255.0.0'"
    
    # Invalid masks
    assert_false "Invalid CIDR: 33" "validate_netmask '33'"
    assert_false "Invalid CIDR: -1" "validate_netmask '-1'"
    assert_false "Invalid mask: 256.255.255.0" "validate_netmask '256.255.255.0'"
}

test_port_validation() {
    console "Testing Port Validation:"
    
    # Valid ports
    assert_true "Valid port: 22" "validate_port '22'"
    assert_true "Valid port: 80" "validate_port '80'"
    assert_true "Valid port: 443" "validate_port '443'"
    assert_true "Valid port: 1" "validate_port '1'"
    assert_true "Valid port: 65535" "validate_port '65535'"
    
    # Invalid ports
    assert_false "Invalid port: 0" "validate_port '0'"
    assert_false "Invalid port: 65536" "validate_port '65536'"
    assert_false "Invalid port: -1" "validate_port '-1'"
    assert_false "Invalid port: abc" "validate_port 'abc'"
    assert_false "Invalid port: empty" "validate_port ''"
}

test_timezone_validation() {
    console "Testing Timezone Validation:"
    
    # Valid timezones
    assert_true "Valid timezone: UTC" "validate_timezone 'UTC'"
    assert_true "Valid timezone: GMT" "validate_timezone 'GMT'"
    assert_true "Valid timezone: Europe/Zurich" "validate_timezone 'Europe/Zurich'"
    assert_true "Valid timezone: America/New_York" "validate_timezone 'America/New_York'"
    assert_true "Valid timezone: Asia/Tokyo" "validate_timezone 'Asia/Tokyo'"
    
    # Invalid timezones
    assert_false "Invalid timezone: invalid" "validate_timezone 'invalid'"
    assert_false "Invalid timezone: 123" "validate_timezone '123'"
    assert_false "Invalid timezone: empty" "validate_timezone ''"
}

test_username_validation() {
    console "Testing Username Validation:"
    
    # Valid usernames
    assert_true "Valid username: admin" "validate_username 'admin'"
    assert_true "Valid username: user123" "validate_username 'user123'"
    assert_true "Valid username: _test" "validate_username '_test'"
    assert_true "Valid username: my-user" "validate_username 'my-user'"
    
    # Invalid usernames
    assert_false "Invalid username: 123user" "validate_username '123user'"
    assert_false "Invalid username: User" "validate_username 'User'"
    assert_false "Invalid username: user@host" "validate_username 'user@host'"
    assert_false "Invalid username: empty" "validate_username ''"
}

test_cidr_conversion() {
    console "Testing CIDR to Netmask Conversion:"
    
    # Test conversions
    local result
    result=$(cidr_to_netmask 24)
    if [[ "$result" == "255.255.255.0" ]]; then
        ((test_passed++))
        console "  ✅ PASS: CIDR 24 → 255.255.255.0"
    else
        ((test_failed++))
        console "  ❌ FAIL: CIDR 24 → $result (expected 255.255.255.0)"
    fi
    
    result=$(cidr_to_netmask 16)
    if [[ "$result" == "255.255.0.0" ]]; then
        ((test_passed++))
        console "  ✅ PASS: CIDR 16 → 255.255.0.0"
    else
        ((test_failed++))
        console "  ❌ FAIL: CIDR 16 → $result (expected 255.255.0.0)"
    fi
    
    result=$(cidr_to_netmask 8)
    if [[ "$result" == "255.0.0.0" ]]; then
        ((test_passed++))
        console "  ✅ PASS: CIDR 8 → 255.0.0.0"
    else
        ((test_failed++))
        console "  ❌ FAIL: CIDR 8 → $result (expected 255.0.0.0)"
    fi
}

test_url_validation() {
    console "Testing URL Validation:"
    
    # Valid URLs
    assert_true "Valid URL: https://github.com" "validate_url 'https://github.com'"
    assert_true "Valid URL: http://example.com" "validate_url 'http://example.com'"
    assert_true "Valid URL: git://repo.git" "validate_url 'git://repo.git'"
    assert_true "Valid URL: ssh://user@host" "validate_url 'ssh://user@host'"
    
    # Invalid URLs
    assert_false "Invalid URL: github.com" "validate_url 'github.com'"
    assert_false "Invalid URL: /path/to/file" "validate_url '/path/to/file'"
    assert_false "Invalid URL: empty" "validate_url ''"
}

test_path_validation() {
    console "Testing Path Validation:"
    
    # Valid paths
    assert_true "Valid path: /root/.ssh/key" "validate_path '/root/.ssh/key'"
    assert_true "Valid path: ~/config" "validate_path '~/config'"
    assert_true "Valid path: ./local" "validate_path './local'"
    
    # Invalid paths
    assert_false "Invalid path: relative" "validate_path 'relative'"
    assert_false "Invalid path: empty" "validate_path ''"
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

setup() {
    # Run all tests
    test_ip_validation
    test_hostname_validation
    test_netmask_validation
    test_port_validation
    test_timezone_validation
    test_username_validation
    test_cidr_conversion
    test_url_validation
    test_path_validation
    
    # Summary
    new_section
    section_header "Test Summary"
    console "  ✅ Passed: $test_passed"
    console "  ❌ Failed: $test_failed"
    console "  📊 Total:  $((test_passed + test_failed))"
    
    if [[ $test_failed -eq 0 ]]; then
        success "All tests passed! 🎉"
        return 0
    else
        error "Some tests failed"
        return 1
    fi
}
