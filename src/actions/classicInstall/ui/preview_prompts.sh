#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action (UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-06
# ==================================================================================================

action_preview() {
    nds_ui_h "Classic NixOS installation (no flake required)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "timezone, locales, keyboard, network, admin user"
    nds_ui_i "bootloader and disk"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "1. partition the target disk (and set up LUKS2 if encryption is enabled)"
    nds_ui_i "2. generate configuration.nix and hardware-configuration.nix"
    nds_ui_i "3. run nixos-install (Nix downloads and builds packages)"
    nds_ui_i "4. offer an install backup zip, then reboot"
    nds_ui_b ""
}
