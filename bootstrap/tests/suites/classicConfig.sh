#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-02
# Description:   classicConfig builder tests (read-only — writes to temp dir only)
# ==================================================================================================

# Reset all encryption-related config vars to a clean state.
_test_reset_encryption_vars() {
    local v
    for v in ENCRYPTION ENCRYPTION_PASSWORD ENCRYPTION_PASSWORD_AUTO \
             ENCRYPTION_PASSWORD_LENGTH ENCRYPTION_KEY ENCRYPTION_KEY_AUTO \
             ENCRYPTION_KEY_LENGTH ENCRYPTION_KEY_BOOT_DEVICE \
             ENCRYPTION_KEY_BOOT_FILE ENCRYPTION_REMOTE_UNLOCK ENCRYPTION_REMOTE_SSH_KEY \
             ENCRYPTION_REMOTE_NETWORK; do
        unset "CONFIG_DATA[$v]"
    done
}

suite_classic_config() {
    local tmp_dir output content

    if ! declare -f nds_nixcfg_build_classic_auto &>/dev/null; then
        warn "classicConfig not loaded — skipping builder tests"
        return 0
    fi

    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    CONFIG_DATA[REGION_TIMEZONE]="Europe/Zurich"
    CONFIG_DATA[REGION_LOCALE_MAIN]="en_US.UTF-8"
    CONFIG_DATA[REGION_KEYBOARD_LAYOUT]="ch"
    CONFIG_DATA[NETWORK_HOSTNAME]="testhost"
    CONFIG_DATA[NETWORK_METHOD]="dhcp"
    CONFIG_DATA[ACCESS_ADMIN_USER]="admin"
    CONFIG_DATA[ACCESS_SUDO_PASSWORD_REQUIRED]="true"
    CONFIG_DATA[ACCESS_SSH_ENABLE]="true"
    CONFIG_DATA[ACCESS_SSH_PORT]="22"
    CONFIG_DATA[ACCESS_SSH_PASSWORD_AUTH]="true"
    CONFIG_DATA[ACCESS_ADMIN_SSH_KEY]=""
    CONFIG_DATA[BOOT_LOADER]="systemd-boot"
    CONFIG_DATA[BOOT_UEFI_MODE]="true"

    # Access block reads the resolved admin password from the runtime secrets dir.
    mkdir -p "$tmp_dir/secrets"
    printf '%s' 'testpass0123456789' > "$tmp_dir/secrets/admin_password.txt"
    export NDS_RUNTIME_DIR="$tmp_dir"

    _test_reset_encryption_vars
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'experimental-features' "configuration.nix"
    assert_contains "$content" 'Europe/Zurich' "configuration.nix"
    assert_contains "$content" 'testhost' "configuration.nix"
    assert_contains "$content" 'hardware-configuration.nix' "configuration.nix"
    # Plain DHCP (no remote unlock) uses NetworkManager.
    assert_contains "$content" 'networkmanager.enable = true' "configuration.nix"

    rm -rf "$tmp_dir"

    # BIOS + mismatched bootloader: must emit GRUB on the target disk, not systemd-boot
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    CONFIG_DATA[DISK_TARGET]="/dev/sda"
    CONFIG_DATA[BOOT_LOADER]="systemd-boot"
    CONFIG_DATA[BOOT_UEFI_MODE]="false"

    _test_reset_encryption_vars
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.loader.grub' "BIOS configuration.nix"
    assert_contains "$content" 'device = "/dev/sda"' "BIOS configuration.nix"
    assert_not_contains "$content" 'systemd-boot.enable' "BIOS configuration.nix"

    rm -rf "$tmp_dir"

    # Password only: no keyFile block (NixOS prompts at boot)
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    _test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_not_contains "$content" 'keyFile' "password-only configuration.nix"
    assert_not_contains "$content" 'boot.initrd.secrets' "password-only configuration.nix"

    rm -rf "$tmp_dir"

    # Key only (raw device): keyFile = device, keyFileSize, keyFileTimeout, no fallback
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    _test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="false"
    CONFIG_DATA[ENCRYPTION_KEY]="true"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_DEVICE]="/dev/disk/by-uuid/abcd-1234"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_FILE]=""
    CONFIG_DATA[ENCRYPTION_KEY_LENGTH]="4096"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'keyFile = "/dev/disk/by-uuid/abcd-1234"' "key-raw configuration.nix"
    assert_contains "$content" 'keyFileSize = 4096' "key-raw configuration.nix"
    assert_contains "$content" 'keyFileTimeout = 30' "key-raw configuration.nix"
    assert_not_contains "$content" 'fallbackToPassword' "key-raw configuration.nix"
    assert_not_contains "$content" 'boot.initrd.secrets' "key-raw configuration.nix"
    assert_not_contains "$content" 'systemd.mounts' "key-raw configuration.nix"

    rm -rf "$tmp_dir"

    # Key only (file on filesystem): systemd mount + keyFile on mounted path
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    _test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="false"
    CONFIG_DATA[ENCRYPTION_KEY]="true"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_DEVICE]="/dev/disk/by-uuid/abcd-1234"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_FILE]="/key.bin"
    CONFIG_DATA[ENCRYPTION_KEY_LENGTH]="4096"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'systemd.mounts' "key-file configuration.nix"
    assert_contains "$content" '/mnt-keyusb' "key-file configuration.nix"
    assert_contains "$content" 'keyFile = "/mnt-keyusb/key.bin"' "key-file configuration.nix"
    assert_not_contains "$content" 'keyFileSize' "key-file configuration.nix"
    assert_not_contains "$content" 'fallbackToPassword' "key-file configuration.nix"

    rm -rf "$tmp_dir"

    # Both (raw device + password): keyFile + fallbackToPassword + short timeout
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    _test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="true"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_DEVICE]="/dev/disk/by-uuid/abcd-1234"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_FILE]=""
    CONFIG_DATA[ENCRYPTION_KEY_LENGTH]="4096"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'keyFile = "/dev/disk/by-uuid/abcd-1234"' "both-raw configuration.nix"
    assert_contains "$content" 'fallbackToPassword = true' "both-raw configuration.nix"
    assert_contains "$content" 'keyFileTimeout = 10' "both-raw configuration.nix"

    rm -rf "$tmp_dir"

    # Remote unlock: initrd SSH + hostKeys + systemd network
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    _test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="true"
    CONFIG_DATA[ENCRYPTION_REMOTE_SSH_KEY]="ssh-ed25519 AAAAfakeKey test@host"
    CONFIG_DATA[ENCRYPTION_REMOTE_NETWORK]="dhcp"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.initrd.network.ssh' "remote-unlock configuration.nix"
    assert_contains "$content" 'ssh-ed25519 AAAAfakeKey test@host' "remote-unlock configuration.nix"
    assert_contains "$content" '/etc/secrets/initrd/ssh_host_ed25519_key' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.systemd.network' "remote-unlock configuration.nix"
    assert_contains "$content" 'matchConfig.Type = "ether"' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'matchConfig.Name = "eth0"' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.availableKernelModules' "remote-unlock configuration.nix"
    assert_contains "$content" 'command="systemctl default"' "remote-unlock configuration.nix"
    assert_contains "$content" 'RequiredForOnline = "routable"' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.systemd.network.enable = true' "remote-unlock configuration.nix"
    assert_contains "$content" 'dhcpV4Config.ClientIdentifier = "mac"' "remote-unlock configuration.nix"
    # Booted system also uses networkd (MAC id) so its IP matches the initrd.
    assert_contains "$content" 'systemd.network.networks."10-wired"' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'networkmanager.enable = true' "remote-unlock configuration.nix"
    assert_contains "$content" 'nds-show-ip' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.systemd.initrdBin' "remote-unlock configuration.nix"

    rm -rf "$tmp_dir"
}
