#!/usr/bin/env bash
# Timezone validation tests

test_timezone() {
    # Valid cases
    assert_valid "timezone" "UTC"
    assert_valid "timezone" "GMT"
    assert_valid "timezone" "Europe/Zurich"
    assert_valid "timezone" "America/New_York"
    assert_valid "timezone" "Asia/Tokyo"
    
    # Invalid cases (if timedatectl available)
    assert_invalid "timezone" "InvalidZone"
    assert_invalid "timezone" "NotACity"
    assert_invalid "timezone" "Europe/FakeCity"
}
