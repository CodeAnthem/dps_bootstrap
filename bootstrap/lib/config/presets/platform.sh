#!/usr/bin/env bash
# ==================================================================================================
# NDS - Platform preset (physical vs virtual machine)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-06-30
# Description:   VM detection and guest tools for classic installs
# ==================================================================================================

platform_init() {
    local detected virt_default on_vm_default tools_default

    detected=$(nds_platform_detect_virt)
    if [[ "$detected" != none ]]; then
        virt_default="$detected"
        on_vm_default=true
        tools_default=true
    else
        virt_default=none
        on_vm_default=false
        tools_default=false
    fi

    nds_configurator_preset_set_display "platform" "Platform"
    nds_configurator_preset_set_priority "platform" 25

    nds_configurator_var_declare RUN_ON_VM \
        display="Running in a virtual machine" \
        input=toggle \
        default="$on_vm_default" \
        help="Auto-detected from the live system. Change if detection is wrong."

    nds_configurator_var_declare VM_TYPE \
        display="Virtual machine type" \
        input=choice \
        default="$virt_default" \
        options="none|vmware|qemu|kvm|xen|hyperv|virtualbox|other" \
        option_labels="none=Physical / unknown|vmware=VMware|qemu=QEMU|kvm=KVM|xen=Xen|hyperv=Hyper-V|virtualbox=VirtualBox|other=Other hypervisor" \
        help="Used to enable the right guest tools in configuration.nix."

    nds_configurator_var_declare VM_GUEST_TOOLS \
        display="Install VM guest tools" \
        input=toggle \
        default="$tools_default" \
        help="Adds open-vm-tools, qemu-guest-agent, or similar to the installed system."
}

platform_get_active() {
    local on_vm

    echo "RUN_ON_VM"

    on_vm=$(nds_configurator_config_get "RUN_ON_VM")
    if [[ "$on_vm" == "true" ]]; then
        echo "VM_TYPE"
        echo "VM_GUEST_TOOLS"
    fi
}
