#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install bundle finish screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-08-04
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_BACKUP_CONFIRM_SKIP
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_REBOOT_SKIP

nds_install_bundle_finish() {
    local bundle_ok=1
    nds_install_bundle_create || bundle_ok=0

    if [[ "$bundle_ok" -ne 0 && -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        _install_gather_context
        nds_ui_section_header "Backup bundle"
        nds_ui_h "Save the restore package for future use"
        nds_ui_b "Copy this zip off the machine before you reboot."
        nds_ui_b "It includes your NDS configuration, install logs, and unlock material (if encrypted)."
        nds_ui_b ""

        if [[ "$NDS_CTX_ENCRYPTION" == "true" ]]; then
            _bundle_ui_colored 35 "Encryption was enabled — saving this zip is important."
            _bundle_ui_colored 35 "Keep it somewhere safe and offline; it contains your unlock secrets."
            nds_ui_b ""
        fi

        _install_bundle_usbkey_instructions
        _install_bundle_remote_copy_hint "$NDS_INSTALL_BUNDLE"

        if nds_skip_menu NDS_BACKUP_CONFIRM_SKIP; then
            log "Backup copy confirmation skipped"
        else
            nds_ask_user_to_proceed "I have copied the package (or do not need it)" || return 1
        fi

        nds_ui_b ""
        nds_ui_h "Next steps"
        nds_ui_b "Personalized first-login and remote-unlock instructions are in the bundle:"
        nds_ui_i "NDS_QUICK_START.md  (at the root of the zip)"
        nds_ui_b "Online guide:"
        nds_ui_i "https://github.com/CodeAnthem/dps_bootstrap/blob/main/src/actions/classicInstall/README.md"
        nds_ui_b ""
        nds_ui_b "Reboot when ready: sudo reboot"
        if nds_skip_menu NDS_REBOOT_SKIP; then
            log "Reboot prompt skipped"
        else
            nds_ask_user_to_proceed "Reboot now?" && reboot
        fi
        return 0
    fi

    if [[ "$bundle_ok" -ne 0 ]]; then
        warn "Install backup package could not be created — fix verification issues before rebooting."
    fi
    nds_ui_b ""
    nds_ui_b "Reboot when ready: sudo reboot"
    if nds_skip_menu NDS_REBOOT_SKIP; then
        log "Reboot prompt skipped"
    else
        nds_ask_user_to_proceed "Reboot now?" && reboot
    fi
    return 0
}

nds_install_finish() {
    nds_install_bundle_finish || return 1
    return 0
}

nds_install_remote_finish() {
    local bundle_ok=1
    nds_install_bundle_create || bundle_ok=0

    nds_ui_section_header "Remote install complete"
    nds_ui_h "Next steps"
    nds_ui_b "nixos-anywhere reboots the target host when finished."
    nds_ui_b "Commit the generated facter.json in your flake host directory."
    nds_ui_b "Enroll the machine age key in .sops.yaml, then: sops updatekeys secrets/secrets.yaml"
    nds_ui_b ""

    if [[ "$bundle_ok" -ne 0 && -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        nds_ui_i "Install backup: ${NDS_INSTALL_BUNDLE}"
        _install_bundle_remote_copy_hint "$NDS_INSTALL_BUNDLE"
    fi

    return 0
}
