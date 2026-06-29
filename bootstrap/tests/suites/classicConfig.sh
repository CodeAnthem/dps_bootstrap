#!/usr/bin/env bash
# ==================================================================================================
# NDS - classicConfig builder tests (read-only — writes to temp dir only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
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
}
