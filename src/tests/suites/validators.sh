#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validator unit tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

suite_validators() {
    assert_valid ip "192.168.1.10"
    assert_invalid ip "256.1.1.1"
    assert_invalid ip "192.168.1.0"
    assert_invalid ip "192.168.1.255"
    assert_invalid ip "not-an-ip"

    assert_valid hostname "myhost"
    assert_valid hostname "my-host-01"
    assert_invalid hostname ""
    assert_invalid hostname "-bad"

    assert_valid path "/etc/nixos"
    assert_valid path "~/flakes"
    assert_valid path "./flake"
    assert_invalid path "relative-no-dot"

    if classify_path "/abs" | grep -qx absolute \
       && classify_path "~/flakes" | grep -qx home \
       && classify_path "./rel" | grep -qx relative; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ classify_path: absolute/home/relative"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ classify_path"
    fi

    assert_valid git_remote "git@github.com:org/repo.git"
    assert_valid git_remote "https://github.com/org/repo.git"
    assert_invalid git_remote "not a url"

    if classify_git_url "git@github.com:a/b.git" | grep -qx scp \
       && classify_git_url "ssh://git@github.com/a/b.git" | grep -qx ssh-scheme \
       && classify_git_url "https://x" | grep -qx https; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ classify_git_url: scp/ssh-scheme/https"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ classify_git_url"
    fi

    if nds_detect_flake_source "git@github.com:o/r.git" | grep -qx remote \
       && nds_detect_flake_source "/tmp/flake" | grep -qx local; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_detect_flake_source: remote/local"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_detect_flake_source"
    fi

    assert_valid toggle "yes"
    assert_valid toggle "false"
    assert_invalid toggle "maybe"
    if normalize_toggle "Y" | grep -qx true && normalize_toggle "0" | grep -qx false; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ normalize_toggle: Y/0"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ normalize_toggle"
    fi

    if nds_validate_same_subnet "192.168.1.10" "255.255.255.0" "192.168.1.1"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_validate_same_subnet: same network"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_validate_same_subnet: same network"
    fi

    if ! nds_validate_same_subnet "192.168.1.10" "255.255.255.0" "10.0.0.1" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_validate_same_subnet: rejects different network"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_validate_same_subnet: should reject different network"
    fi
}
