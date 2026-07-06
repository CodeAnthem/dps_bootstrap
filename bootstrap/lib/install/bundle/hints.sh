#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install bundle UI hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-06
# ==================================================================================================

_nds_ui_colored() {
    local color="$1"
    local text="$2"
    nds_ui_init
    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf '%s\033[%sm%s\033[0m\n' "$NDS_UI_INDENT_B" "$color" "$text" >&2
    else
        printf '%s%s\n' "$NDS_UI_INDENT_B" "$text" >&2
    fi
}

_nds_install_bundle_remote_copy_hint() {
    local bundle_path="$1"
    local ssh_user host local_name

    ssh_user=$(nds_install_ssh_user)
    host=$(nds_install_bundle_host_ip)
    [[ -z "$host" ]] && return 0

    local_name=$(nds_install_bundle_local_name)
    [[ "$bundle_path" == *.tar.gz ]] && local_name="${local_name%.zip}.tar.gz"

    nds_ui_b "Backup it from your local machine:"
    nds_ui_i "SCP:"
    nds_ui_i "  scp ${ssh_user}@${host}:${bundle_path} ./${local_name}"
    nds_ui_b ""
    nds_ui_i "SSH:"
    nds_ui_i "  ssh ${ssh_user}@${host} \"cat ${bundle_path}\" > ${local_name}"
    nds_ui_b ""
}

_nds_install_bundle_usbkey_instructions() {
    _nixinstall_gather_context
    [[ "$NDS_CTX_ENCRYPTION" == "true" ]] || return 0
    [[ "$NDS_CTX_ENCRYPTION_KEY" == "true" ]] || return 0

    nds_ui_b ""
    nds_ui_h "Prepare your USB key (required to boot)"
    nds_ui_i "The LUKS key is in this zip at secrets/luks_key.bin."

    if [[ -z "$NDS_CTX_KEY_BOOT_FILE" ]]; then
        nds_ui_i "Copy it to a USB stick as RAW bytes BEFORE rebooting:"
        nds_ui_i "  dd if=luks_key.bin of=<usb-device> bs=4096 count=1"
        nds_ui_i "Plug that USB in at every boot. Its device path must match:"
        nds_ui_i "  ENCRYPTION_KEY_BOOT_DEVICE = ${NDS_CTX_KEY_BOOT_DEVICE}"
    else
        nds_ui_i "Copy it to a file on a USB stick BEFORE rebooting:"
        nds_ui_i "  mount <usb-device> /mnt/usb"
        nds_ui_i "  cp luks_key.bin /mnt/usb/${NDS_CTX_KEY_BOOT_FILE}"
        nds_ui_i "  umount /mnt/usb"
        nds_ui_i "Plug that USB in at every boot. Its device path must match:"
        nds_ui_i "  ENCRYPTION_KEY_BOOT_DEVICE = ${NDS_CTX_KEY_BOOT_DEVICE}"
    fi

    if [[ "$NDS_CTX_ENCRYPTION_PASSWORD" != "true" ]]; then
        nds_ui_b ""
        _nds_ui_colored 31 "WARNING: key-only mode (no password)."
        _nds_ui_colored 31 "If this USB is lost, stolen, or corrupted, the system CANNOT boot."
        _nds_ui_colored 31 "There is no fallback. Consider re-installing with a password too."
    fi
}
