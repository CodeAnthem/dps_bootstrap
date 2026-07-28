#!/usr/bin/env bash
# ==================================================================================================
# NDS - Standalone module tests (no full NDS bootstrap)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# ==================================================================================================

suite_standalone() {
    local out parsed host owner repo

    out=$(nds_git_owner_slug "https://github.com/CodeAnthem/dps_swarm.git")
    if [[ "$out" == "codeanthem" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_owner_slug: extracts owner slug"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_owner_slug: expected codeanthem got $out"
    fi

    out=$(nds_git_repo_slug "CodeAnthem" "dps_swarm")
    if [[ "$out" == "codeanthem-dps-swarm" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_repo_slug: normalizes owner and repo"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_repo_slug: expected codeanthem-dps-swarm got $out"
    fi

    out=$(nds_git_deploy_key_basename "CodeAnthem" "thundercast")
    if [[ "$out" == "nds_deploy_codeanthem_thundercast" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_deploy_key_basename"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_deploy_key_basename: got $out"
    fi

    out=$(nds_git_owner_repo_from_deploy_basename "nds_deploy_codeanthem_thundercast")
    if [[ "$out" == "codeanthem/thundercast" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_owner_repo_from_deploy_basename"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_owner_repo_from_deploy_basename: got $out"
    fi

    out=$(nds_git_session_key_title_for "codeanthem" "control-toolkit")
    if [[ "$out" == "nds-codeanthem-control-toolkit" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_session_key_title_for"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_session_key_title_for: got $out"
    fi

    out=$(nds_install_disk_part "/dev/nvme0n1" 2)
    if [[ "$out" == "/dev/nvme0n1p2" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_install_disk_part: nvme suffix"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_disk_part: nvme got $out"
    fi

    out=$(nds_install_disk_part "/dev/sda" 2)
    if [[ "$out" == "/dev/sda2" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_install_disk_part: sd suffix"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_disk_part: sd got $out"
    fi

    out=$(nds_install_urandom_chars 16)
    if [[ ${#out} -eq 16 && "$out" =~ ^[A-Za-z0-9]+$ ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_install_urandom_chars"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_urandom_chars: bad output"
    fi

    tmpdir=$(mktemp -d)
    if nds_install_write_admin_password true 12 "" "$tmpdir/secrets"; then
        if [[ -s "$tmpdir/secrets/admin_password.txt" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ nds_install_write_admin_password"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ nds_install_write_admin_password: empty file"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_write_admin_password: failed"
    fi
    rm -rf "$tmpdir"
}
