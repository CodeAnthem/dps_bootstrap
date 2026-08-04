#!/usr/bin/env bash
# ==================================================================================================
# NDS - Platform preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# ==================================================================================================

platform_defaults() {
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
    nds_cfg_set PLATFORM_RUN_ON_VM "$on_vm_default"
    nds_cfg_set PLATFORM_VM_TYPE "$virt_default"
    nds_cfg_set PLATFORM_VM_GUEST_TOOLS "$tools_default"
}

platform_configure() {
    nds_cfg_section_title "Platform"
    nds_cfg_ask_toggle PLATFORM_RUN_ON_VM "Running in a virtual machine" "$(nds_cfg_get PLATFORM_RUN_ON_VM)"
    if nds_cfg_true PLATFORM_RUN_ON_VM; then
        nds_cfg_ask_choice PLATFORM_VM_TYPE "Virtual machine type" \
            "none|vmware|qemu|kvm|xen|hyperv|virtualbox|other" \
            "none=Physical / unknown|vmware=VMware|qemu=QEMU|kvm=KVM|xen=Xen|hyperv=Hyper-V|virtualbox=VirtualBox|other=Other" \
            "$(nds_cfg_get PLATFORM_VM_TYPE)"
        nds_cfg_ask_toggle PLATFORM_VM_GUEST_TOOLS "Install VM guest tools" true
    fi
}

platform_summary() {
    nds_cfg_summary_row "Virtual machine" "$(nds_cfg_display_toggle "$(nds_cfg_get PLATFORM_RUN_ON_VM)")"
    if nds_cfg_true PLATFORM_RUN_ON_VM; then
        nds_cfg_summary_row "VM type" "$(nds_cfg_get PLATFORM_VM_TYPE)"
        nds_cfg_summary_row "Guest tools" "$(nds_cfg_display_toggle "$(nds_cfg_get PLATFORM_VM_GUEST_TOOLS)")"
    fi
}

platform_validate() {
    return 0
}

NDS_PRESET_PRIORITY=25
NDS_PRESET_DISPLAY="Platform"
