#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install pipeline tests (read-only / mocked)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-08
# ==================================================================================================

suite_install() {
    local out

    _nds_nix_store_free_mb() { echo 100; }
    out=$(_nds_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == "experimental-features = nix-command flakes" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: no store override before target root is mounted"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: expected no store override before /mnt is mounted"
        console "    got: $(printf '%q' "$out")"
    fi
    assert_not_contains "$out" "flakes store" "nix config"

    local fake_root
    fake_root=$(mktemp -d)
    mkdir -p "${fake_root}/nix/store"
    export NDS_NIX_TARGET_ROOT="$fake_root"
    export NDS_NIX_INSTALL_STORE_FORCE=1
    out=$(_nds_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == *$'\n'"store = ${fake_root}"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: chroot store when target root is mounted"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: expected chroot store ${fake_root}"
        console "    got: $(printf '%q' "$out")"
    fi
    unset NDS_NIX_TARGET_ROOT NDS_NIX_INSTALL_STORE_FORCE
    rm -rf "$fake_root"

    _nds_nix_store_free_mb() { echo 8192; }
    out=$(_nds_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == "experimental-features = nix-command flakes" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: large store unchanged"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: large store should pass through base config"
    fi
    unset -f _nds_nix_store_free_mb

    nds_test_snapshot_config
    CONFIG_DATA[BOOT_LOADER]=grub
    out=$(_nixinstall_efi_loader_path)
    if [[ "$out" == '\\EFI\\nixos\\grubx64.efi' ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ EFI loader path: grub"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ EFI loader path: grub expected, got $out"
    fi

    CONFIG_DATA[BOOT_LOADER]=systemd-boot
    out=$(_nixinstall_efi_loader_path)
    if [[ "$out" == '\\EFI\\systemd\\systemd-bootx64.efi' ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ EFI loader path: systemd-boot"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ EFI loader path: systemd-boot expected, got $out"
    fi
    nds_test_reset_config

    if [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
        if _nds_install_verify_grub_bios /dev/null; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ verify grub bios: should fail without grub.cfg on /mnt"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ verify grub bios: requires grub.cfg on /mnt"
        fi
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ verify grub bios: skipped (live /mnt layout)"
    fi

    if declare -f _nds_run_age_keygen &>/dev/null; then
        if grep -qE 'env NIX_CONFIG=.*_nds_run_age_keygen' "${BASH_SOURCE[0]%/*}/../../lib/install/sops.sh" 2>/dev/null; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ sops: age-keygen must not be invoked via env as external command"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ sops: age-keygen invoked as shell function"
        fi
    fi

    if declare -f _nds_nix_canonical_store_path &>/dev/null; then
        out=$(_nds_nix_canonical_store_path /mnt /mnt/nix/store/abc-nixos-system-host)
        if [[ "$out" == '/nix/store/abc-nixos-system-host' ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ canonical store path: strips /mnt prefix"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ canonical store path: expected /nix/store/… got $out"
        fi
    fi

    if declare -f _nds_nix_flake_system_ref &>/dev/null; then
        out=$(_nds_nix_flake_system_ref "control-toolkit")
        if [[ "$out" == 'nixosConfigurations."control-toolkit".config.system.build.toplevel' ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake system ref: nixosConfigurations host attr"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake system ref: expected toplevel attr, got $out"
        fi
    fi

    if declare -f nds_install_diag_snapshot &>/dev/null; then
        local diag_log
        diag_log=$(mktemp)
        export NDS_INSTALL_DIAG_LOG="$diag_log"
        nds_install_diag_snapshot "test"
        if grep -q '=== test @' "$diag_log" && grep -q 'system_profile=' "$diag_log"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ install_diag: compact snapshot in diag log"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ install_diag: compact snapshot"
        fi
        rm -f "$diag_log"
        unset NDS_INSTALL_DIAG_LOG
    fi
}
