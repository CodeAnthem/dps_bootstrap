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
_nixcfg_remoteUnlock_generate() {
    local remote_port="$1"
    local ssh_key="$2"
    local net_mode="$3"
    local ip="${4:-}"
    local prefix="${5:-24}"
    local gateway="${6:-}"

    local net_block
    if [[ "$net_mode" == "static" ]]; then
        local ip_only="${ip%/*}"
        net_block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.initrd.systemd.network.networks."10-remote-unlock" = {
  matchConfig.Type = "ether";
  address = [ "@@IP@@/@@PREFIX@@" ];
  gateway = [ "@@GATEWAY@@" ];
  linkConfig.RequiredForOnline = "routable";
};
EOF
)" @@IP@@ "$ip_only" @@PREFIX@@ "$prefix" @@GATEWAY@@ "$gateway")
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

    # Quoted heredoc: bash expands nothing, so Nix ${pkgs...} stays literal.
    # Only @@TOKEN@@ placeholders are filled in.
    #
    # nds-show-ip uses two plain-binary ExecStart entries (echo + ip) on
    # purpose: a writeShellScript needs bash inside the initrd, which is not
    # guaranteed there, so the service would silently never run. echo and ip are
    # pulled in via initrdBin and always work. StandardOutput=journal+console is
    # the channel that reliably reaches the visible console in initrd.
    #
    # command="systemctl default" runs the unlock prompt directly on SSH login;
    # 2>/dev/null hides the harmless "system scope bus" notice (no D-Bus in
    # initrd). boot.initrd.systemd.network.enable is required or networkd never
    # starts and SSH is unreachable.
    local block
    block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.initrd.network.enable = true;
boot.initrd.network.ssh = {
  enable = true;
  port = @@REMOTE_PORT@@;
  authorizedKeys = [ ''command="systemctl default 2>/dev/null" @@SSH_KEY@@'' ];
  hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
};
boot.initrd.systemd.enable = true;
boot.initrd.systemd.network.enable = true;
boot.initrd.availableKernelModules = [ "e1000" "e1000e" "vmxnet3" "virtio_net" "r8169" "igb" "ixgbe" "tg3" ];
boot.initrd.systemd.initrdBin = [ pkgs.iproute2 ];
boot.initrd.systemd.services.nds-show-ip = {
  description = "Show IP for remote LUKS unlock";
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
      "${pkgs.coreutils}/bin/echo '>>> Remote LUKS unlock ready. Connect: ssh -p @@REMOTE_PORT@@ root@<address shown below>'"
      "${pkgs.iproute2}/bin/ip -4 -brief address show scope global"
    ];
  };
};
@@NET_BLOCK@@
EOF
)" @@REMOTE_PORT@@ "$remote_port" @@SSH_KEY@@ "$ssh_key" @@NET_BLOCK@@ "$net_block")

    nds_nixcfg_register "remoteUnlock" "$block" 13
}
