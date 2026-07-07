#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install pipeline tests (read-only / mocked)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

suite_install() {
    local out

    _nds_nix_store_free_mb() { echo 100; }
    out=$(_nds_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == *$'\n'"store = /mnt/var/nds-build-store" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: store on separate line"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: expected newline-separated store setting"
        console "    got: $(printf '%q' "$out")"
    fi
    assert_not_contains "$out" "flakes store" "nix config"

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
}
