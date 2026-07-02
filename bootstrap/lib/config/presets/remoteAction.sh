#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote flake action preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# ==================================================================================================

remoteAction_defaults() {
    nds_cfg_set FLAKE_REPO_URL ""
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/opt/flake"
    nds_cfg_set FLAKE_HOST ""
    nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
}

remoteAction_configure() {
    nds_cfg_section_title "Remote flake action"
    nds_cfg_ask_url FLAKE_REPO_URL "Remote flake Git URL" "" true
    nds_cfg_ask_path FLAKE_INSTALL_PATH "Flake path on installed disk" "/mnt/opt/flake" true
    nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
    nds_cfg_ask_path FLAKE_HOST_DIR "Host directory inside flake" "hosts/x86_64-linux" false
    nds_cfg_ask_choice FLAKE_HARDWARE_PLACEMENT "Hardware configuration" "host-dir|etc-nixos|skip" \
        "host-dir=Copy into flake host dir|etc-nixos=Keep in /etc/nixos|skip=Flake handles hardware" "host-dir"
}

remoteAction_summary() {
    nds_cfg_summary_row "Git URL" "$(nds_cfg_get FLAKE_REPO_URL)"
    nds_cfg_summary_row "Host name" "$(nds_cfg_get FLAKE_HOST)"
    nds_cfg_summary_row "Hardware" "$(nds_cfg_get FLAKE_HARDWARE_PLACEMENT)"
}

remoteAction_prompt_errors() {
    nds_cfg_section_title "Remote flake action"
    while ! remoteAction_validate &>/dev/null; do
        if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
            nds_cfg_ask_url FLAKE_REPO_URL "Remote flake Git URL" "" true
            continue
        fi
        if [[ -z "$(nds_cfg_get FLAKE_HOST)" ]] || ! validate_hostname "$(nds_cfg_get FLAKE_HOST)" 2>/dev/null; then
            nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
            continue
        fi
        break
    done
}

remoteAction_validate() {
    [[ -n "$(nds_cfg_get FLAKE_REPO_URL)" ]] || { validation_error "Remote flake Git URL is required"; return 1; }
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || { validation_error "Host name is required"; return 1; }
    validate_hostname "$(nds_cfg_get FLAKE_HOST)" || {
        validation_error "$(error_msg_hostname)"
        return 1
    }
    return 0
}

NDS_PRESET_PRIORITY=20
NDS_PRESET_DISPLAY="Remote flake action"
