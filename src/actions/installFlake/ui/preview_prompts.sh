#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action (UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-06
# ==================================================================================================

action_preview() {
    nds_ui_h "Install NixOS from your flake"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "ask for flake URL (or path) and prove git access (root + flake.lock inputs)"
    nds_ui_i "list nixosConfigurations and let you pick a host"
    nds_ui_i "ask install mode / target disk (or remote IP)"
    nds_ui_i "open the settings manager for boot / disk / encryption"
    nds_ui_i "local: partition, facter, flake install — or remote: nixos-anywhere"
    nds_ui_b ""
}
