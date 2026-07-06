#!/usr/bin/env bash
# ==================================================================================================
# NDS - nixWriter classic install orchestration
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Reads configurator answers and calls pure nixWriter blocks
# ==================================================================================================

# Description: Register flake experimental features block.
nds_nixcfg_base_auto() {
    nds_nixcfg_register "nix" 'nix.settings.experimental-features = [ "nix-command" "flakes" ];' 5
}

# Description: Build access block from configurator + runtime secrets.
nds_nixcfg_access_auto() {
    local admin_user sudo_password ssh_enable ssh_port ssh_pw_auth admin_ssh_key admin_password pw_file
    admin_user=$(nds_config_get "access" "ACCESS_ADMIN_USER")
    sudo_password=$(nds_config_get "access" "ACCESS_SUDO_PASSWORD_REQUIRED")
    ssh_enable=$(nds_config_get "access" "ACCESS_SSH_ENABLE")
    ssh_port=$(nds_config_get "access" "ACCESS_SSH_PORT")
    ssh_pw_auth=$(nds_config_get "access" "ACCESS_SSH_PASSWORD_AUTH")
    admin_ssh_key=$(nds_config_get "access" "ACCESS_ADMIN_SSH_KEY")
    pw_file="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets/admin_password.txt"
    admin_password=""
    [[ -f "$pw_file" ]] && admin_password=$(<"$pw_file")
    if [[ -z "$admin_password" ]]; then
        warn "Admin password file missing — falling back to 'changeme'. Run _nixinstall_generate_access_secrets first."
        admin_password="changeme"
    fi
    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_pw_auth" "$admin_ssh_key" "$admin_password"
}

# Description: Build boot block from configurator answers.
nds_nixcfg_boot_auto() {
    local bootloader uefi disk
    bootloader=$(nds_config_get "boot" "BOOT_LOADER")
    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE")
    disk=$(nds_config_get "disk" "DISK_TARGET")
    _nixcfg_boot_generate "$bootloader" "$uefi" "$disk"
}

# Description: Build flake boot module (lib.mkForce) from configurator answers.
nds_nixcfg_boot_auto_flake() {
    local bootloader uefi disk
    bootloader=$(nds_config_get "boot" "BOOT_LOADER")
    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE")
    disk=$(nds_config_get "disk" "DISK_TARGET")
    _nixcfg_boot_generate_flake "$bootloader" "$uefi" "$disk"
}

# Description: Build LUKS unlock block from encryption preset answers.
nds_nixcfg_luks_auto() {
    local encryption use_password use_key key_device key_file key_length
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    [[ "$encryption" == "true" ]] || return 0
    use_password=$(nds_config_get "encryption" "ENCRYPTION_PASSWORD")
    use_key=$(nds_config_get "encryption" "ENCRYPTION_KEY")
    [[ "$use_key" == "true" ]] || return 0
    key_device=$(nds_config_get "encryption" "ENCRYPTION_KEY_BOOT_DEVICE")
    key_file=$(nds_config_get "encryption" "ENCRYPTION_KEY_BOOT_FILE")
    key_length=$(nds_config_get "encryption" "ENCRYPTION_KEY_LENGTH")
    _nixcfg_luks_generate "$use_password" "$use_key" "$key_device" "$key_file" "$key_length"
}

# Description: Build network block from network preset answers.
nds_nixcfg_network_auto() {
    local hostname method ip gateway dns1 dns2 mask_val prefix remote_unlock
    hostname=$(nds_config_get "network" "NETWORK_HOSTNAME")
    method=$(nds_config_get "network" "NETWORK_METHOD")
    ip=$(nds_config_get "network" "NETWORK_IP")
    gateway=$(nds_config_get "network" "NETWORK_GATEWAY")
    dns1=$(nds_config_get "network" "NETWORK_DNS_PRIMARY")
    dns2=$(nds_config_get "network" "NETWORK_DNS_SECONDARY")
    mask_val=$(nds_config_get "network" "NETWORK_MASK")
    remote_unlock=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_UNLOCK" 2>/dev/null || true)
    if [[ "$method" == "static" ]]; then
        prefix=$(_nixcfg_netmask_to_prefix "$mask_val")
        _nixcfg_network_static "$hostname" "$ip" "$gateway" "$prefix" "$dns1" "$dns2"
    else
        _nixcfg_network_dhcp "$hostname" "$dns1" "$dns2" "$remote_unlock"
    fi
}

# Description: Build initrd SSH remote-unlock block from encryption + network answers.
nds_nixcfg_remoteUnlock_auto() {
    local encryption remote_unlock ssh_key net_mode remote_port ip gateway mask_val prefix ip_only
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    remote_unlock=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_UNLOCK")
    [[ "$encryption" == "true" && "$remote_unlock" == "true" ]] || return 0
    ssh_key=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_SSH_KEY")
    net_mode=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_NETWORK")
    remote_port=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_PORT")
    [[ -n "$remote_port" ]] || remote_port=2222
    if [[ "$net_mode" == "static" ]]; then
        ip=$(nds_config_get "network" "NETWORK_IP")
        gateway=$(nds_config_get "network" "NETWORK_GATEWAY")
        mask_val=$(nds_config_get "network" "NETWORK_MASK")
        prefix=$(_nixcfg_netmask_to_prefix "${mask_val:-24}")
        ip_only="${ip%/*}"
        _nixcfg_remoteUnlock_generate "$remote_port" "$ssh_key" "static" "$ip_only" "$prefix" "$gateway"
    else
        _nixcfg_remoteUnlock_generate "$remote_port" "$ssh_key" "dhcp"
    fi
}

# Description: Build region block from region preset answers.
nds_nixcfg_region_auto() {
    local timezone locale_main locale_extra keyboard_layout keyboard_variant
    timezone=$(nds_config_get "region" "REGION_TIMEZONE")
    locale_main=$(nds_config_get "region" "REGION_LOCALE_MAIN")
    locale_extra=$(nds_config_get "region" "REGION_LOCALE_EXTRA")
    keyboard_layout=$(nds_config_get "region" "REGION_KEYBOARD_LAYOUT")
    keyboard_variant=$(nds_config_get "region" "REGION_KEYBOARD_VARIANT")
    _nixcfg_region_generate "$timezone" "$locale_main" "$locale_extra" "$keyboard_layout" "$keyboard_variant"
}

# Description: Build VM guest-tools block from platform preset answers.
nds_nixcfg_virtualisation_auto() {
    local on_vm vm_type guest_tools
    on_vm=$(nds_config_get "platform" "PLATFORM_RUN_ON_VM")
    vm_type=$(nds_config_get "platform" "PLATFORM_VM_TYPE")
    guest_tools=$(nds_config_get "platform" "PLATFORM_VM_GUEST_TOOLS")
    [[ "$on_vm" == "true" && "$guest_tools" == "true" ]] || return 0
    _nixcfg_virtualisation_generate "$vm_type"
}

# Description: Assemble all classic configuration blocks from configurator state.
nds_nixcfg_build_classic_auto() {
    nds_nixcfg_clear
    nds_nixcfg_base_auto
    nds_nixcfg_boot_auto
    nds_nixcfg_luks_auto
    nds_nixcfg_remoteUnlock_auto
    nds_nixcfg_network_auto
    nds_nixcfg_access_auto
    nds_nixcfg_region_auto
    nds_nixcfg_virtualisation_auto
    return 0
}

# Description: Build and write classic configuration.nix to the runtime config dir.
nds_nixcfg_write_classic() {
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "${NDS_RUNTIME_DIR}/config/configuration.nix"
}

# Description: Write boot settings into a flake host module (lib.mkForce).
nds_nixcfg_write_boot_module() {
    local output_file="$1"
    nds_nixcfg_clear
    nds_nixcfg_boot_auto_flake
    nds_nixcfg_write_module "$output_file"
    nds_nixcfg_clear
}
