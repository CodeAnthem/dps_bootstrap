#!/usr/bin/env bash
# ==================================================================================================
# NDS - classicConfig builder tests (read-only — writes to temp dir only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
# ==================================================================================================

suite_classic_config() {
    local tmp_dir output

    if ! declare -f nds_nixcfg_build_classic_auto &>/dev/null; then
        warn "classicConfig not loaded — skipping builder tests"
        return 0
    fi

    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    CONFIG_DATA[TIMEZONE]="Europe/Zurich"
    CONFIG_DATA[LOCALE_MAIN]="en_US.UTF-8"
    CONFIG_DATA[KEYBOARD_LAYOUT]="ch"
    CONFIG_DATA[HOSTNAME]="testhost"
    CONFIG_DATA[NETWORK_METHOD]="dhcp"
    CONFIG_DATA[ADMIN_USER]="admin"
    CONFIG_DATA[SUDO_PASSWORD_REQUIRED]="true"
    CONFIG_DATA[SSH_ENABLE]="true"
    CONFIG_DATA[SSH_PORT]="22"
    CONFIG_DATA[SSH_USE_KEY]="true"
    CONFIG_DATA[BOOTLOADER]="systemd-boot"
    CONFIG_DATA[UEFI_MODE]="true"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    local content
    content=$(<"$output")

    assert_contains "$content" 'experimental-features' "configuration.nix"
    assert_contains "$content" 'Europe/Zurich' "configuration.nix"
    assert_contains "$content" 'testhost' "configuration.nix"
    assert_contains "$content" 'hardware-configuration.nix' "configuration.nix"

    rm -rf "$tmp_dir"

    # BIOS + mismatched bootloader: must emit GRUB on the target disk, not systemd-boot
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    CONFIG_DATA[DISK_TARGET]="/dev/sda"
    CONFIG_DATA[BOOTLOADER]="systemd-boot"
    CONFIG_DATA[UEFI_MODE]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.loader.grub' "BIOS configuration.nix"
    assert_contains "$content" 'device = "/dev/sda"' "BIOS configuration.nix"
    assert_not_contains "$content" 'systemd-boot.enable' "BIOS configuration.nix"

    rm -rf "$tmp_dir"

    # LUKS keyfile unlock must embed the key in the initrd via boot.initrd.secrets
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_USE_PASSPHRASE]="false"
    CONFIG_DATA[REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.initrd.secrets' "LUKS configuration.nix"
    assert_contains "$content" '"/etc/luks-keys/cryptroot"' "LUKS configuration.nix"

    rm -rf "$tmp_dir"
}
