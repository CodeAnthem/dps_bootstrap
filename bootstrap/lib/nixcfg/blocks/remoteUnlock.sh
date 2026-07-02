#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# Description:   Initrd SSH remote-unlock Nix config
# Feature:       boot.initrd.network.ssh (dropbear/unssh) + systemd initrd
#                networking. Host key is embedded automatically via the
#                hostKeys option (NixOS wires it into the initrd secrets).
# ==================================================================================================

# Auto-mode: reads from the disk configurator answers.
# Emits initrd SSH server + systemd initrd networking so the user can SSH
# into the initrd and unlock LUKS with `systemctl default`.
nds_nixcfg_remoteUnlock_auto() {
    local encryption remote_unlock ssh_key net_mode
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    remote_unlock=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_UNLOCK")
    [[ "$encryption" == "true" && "$remote_unlock" == "true" ]] || return 0

    ssh_key=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_SSH_KEY")
    net_mode=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_NETWORK")

    # Match any wired NIC by type instead of a fixed name — the initrd uses
    # predictable names (ens33, enp0s3, …), so a hardcoded "eth0" matches
    # nothing and the interface never comes up.
    local net_block
    if [[ "$net_mode" == "static" ]]; then
        local ip gateway mask_val prefix
        ip=$(nds_config_get "network" "NETWORK_IP")
        gateway=$(nds_config_get "network" "NETWORK_GATEWAY")
        mask_val=$(nds_config_get "network" "NETWORK_MASK")
        prefix=$(_nixcfg_netmask_to_prefix "${mask_val:-24}")
        local ip_only="${ip%/*}"
        net_block=$(cat <<EOF
boot.initrd.systemd.network.networks."10-remote-unlock" = {
  matchConfig.Type = "ether";
  address = [ "${ip_only}/${prefix}" ];
  gateway = [ "${gateway}" ];
  linkConfig.RequiredForOnline = "routable";
};
EOF
)
    else
        # ClientIdentifier = "mac" makes the initrd request its DHCP lease by
        # MAC address — the same identity the booted system uses (see
        # network.sh) — so the DHCP server hands out the SAME IP in the initrd
        # and after boot. Otherwise the initrd gets its own, unknowable lease.
        net_block=$(cat <<'EOF'
boot.initrd.systemd.network.networks."10-remote-unlock" = {
  matchConfig.Type = "ether";
  networkConfig.DHCP = "ipv4";
  dhcpV4Config.ClientIdentifier = "mac";
  linkConfig.RequiredForOnline = "routable";
};
EOF
)
    fi

    local block
    block=$(cat <<EOF
# Initrd SSH for remote LUKS unlock
boot.initrd.network.enable = true;
boot.initrd.network.ssh = {
  enable = true;
  port = 22;
  # command="systemctl default" makes the SSH login run the unlock prompt
  # directly instead of dropping into an initrd shell. stderr is dropped to
  # silence the harmless "Failed to connect to system scope bus via local
  # transport" notice: there is no D-Bus daemon in the initrd, so systemctl
  # falls back to systemd's private socket - the passphrase prompt (written to
  # the tty, not stderr) still appears and unlocking works.
  authorizedKeys = [ ''command="systemctl default 2>/dev/null" ${ssh_key}'' ];
  hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
};
boot.initrd.systemd.enable = true;
# Without this, systemd-networkd never starts in the initrd, the NIC stays
# down, and initrd SSH is unreachable - this is required, not optional.
boot.initrd.systemd.network.enable = true;
# Common wired NIC drivers so the initrd can bring up the network for SSH.
# availableKernelModules merges with hardware-configuration.nix; unknown
# modules are simply ignored.
boot.initrd.availableKernelModules = [ "e1000" "e1000e" "vmxnet3" "virtio_net" "r8169" "igb" "ixgbe" "tg3" ];
# Print the address + a connect hint to the console once the network is up, so
# the remote-unlock IP is visible instead of having to be guessed. Best-effort
# and non-blocking: if it fails, unlocking still works.
boot.initrd.systemd.initrdBin = [ pkgs.iproute2 ];
boot.initrd.systemd.services.nds-show-ip = {
  description = "Show IP address for remote LUKS unlock";
  wantedBy = [ "initrd.target" ];
  after = [ "systemd-networkd-wait-online.service" ];
  wants = [ "systemd-networkd-wait-online.service" ];
  unitConfig.DefaultDependencies = false;
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    StandardOutput = "journal+console";
    StandardError = "journal+console";
    ExecStart = [
      "\${pkgs.coreutils}/bin/echo '>>> Remote LUKS unlock ready. SSH to root@ the address below and enter the passphrase:'"
      "\${pkgs.iproute2}/bin/ip -4 -brief address show scope global"
    ];
  };
};
${net_block}
EOF
)

    nds_nixcfg_register "remoteUnlock" "$block" 13
}
