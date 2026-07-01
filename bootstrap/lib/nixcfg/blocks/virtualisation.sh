#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic config - Virtualisation guest tools
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-06-30
# Description:   VM guest agents for classicInstall
# ==================================================================================================

nds_nixcfg_virtualisation_auto() {
    local on_vm vm_type guest_tools
    on_vm=$(nds_config_get "platform" "RUN_ON_VM")
    vm_type=$(nds_config_get "platform" "VM_TYPE")
    guest_tools=$(nds_config_get "platform" "VM_GUEST_TOOLS")

    [[ "$on_vm" == "true" && "$guest_tools" == "true" ]] || return 0
    _nixcfg_virtualisation_generate "$vm_type"
}

_nixcfg_virtualisation_generate() {
    local vm_type="$1"
    local output=""

    case "$vm_type" in
        vmware)
            output="virtualisation.vmware.guest.enable = true;"
            ;;
        qemu|kvm)
            output="virtualisation.qemu.guest.enable = true;"
            ;;
        hyperv)
            output="virtualisation.hypervGuest.enable = true;"
            ;;
        virtualbox)
            output="virtualisation.virtualbox.guest.enable = true;"
            ;;
        xen)
            output="# Xen guest — add hypervisor-specific guest tools in configuration.nix if needed"
            ;;
        other)
            output="# Unknown hypervisor — add guest tools in configuration.nix if needed"
            ;;
        *)
            return 0
            ;;
    esac

    nds_nixcfg_register "virtualisation" "$output" 55
}
