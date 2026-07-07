#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-03
# ==================================================================================================

installFlake_defaults() {
    nds_cfg_set INSTALL_MODE "local"
    nds_cfg_set REMOTE_TARGET_IP ""
    nds_cfg_set FLAKE_LOCATION ""
    nds_cfg_set FLAKE_SOURCE "remote"
    nds_cfg_set FLAKE_REPO_URL ""
    nds_cfg_set FLAKE_LOCAL_PATH ""
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/opt/flake"
    nds_cfg_set FLAKE_HOST ""
    nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
}

# Description: Prompt for a single flake location and auto-classify it as a remote
# git URL or a local path. Populates FLAKE_SOURCE, FLAKE_REPO_URL and
# FLAKE_LOCAL_PATH so downstream install steps keep their existing contract.
_installFlake_ask_location() {
    local value src current
    current="$(nds_cfg_get FLAKE_REPO_URL)"
    [[ -z "$current" ]] && current="$(nds_cfg_get FLAKE_LOCAL_PATH)"
    nds_cfg_set FLAKE_LOCATION "$current"
    while true; do
        value=$(_nds_cfg_prompt_value FLAKE_LOCATION "Flake location" \
            "(git URL, git@host:owner/repo, or /path)" true) || continue
        [[ -z "$value" ]] && value="$current"
        if [[ -z "$value" ]]; then
            validation_error "Flake location is required"
            continue
        fi
        if ! validate_flake_location "$value"; then
            nds_ui_b "  Error: not a valid git URL or local path"
            continue
        fi
        src=$(nds_detect_flake_source "$value")
        nds_cfg_set FLAKE_LOCATION "$value"
        nds_cfg_set FLAKE_SOURCE "$src"
        if [[ "$src" == remote ]]; then
            nds_cfg_set FLAKE_REPO_URL "$value"
            nds_cfg_set FLAKE_LOCAL_PATH ""
        else
            nds_cfg_set FLAKE_LOCAL_PATH "$value"
            nds_cfg_set FLAKE_REPO_URL ""
        fi
        [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value (detected: $src)"
        return 0
    done
}

installFlake_configure() {
    nds_cfg_section_title "Install mode"
    nds_cfg_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "local"
    if nds_cfg_is INSTALL_MODE remote; then
        nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
    fi
    nds_cfg_section_title "Your flake"
    _installFlake_ask_location
    nds_cfg_ask_path FLAKE_INSTALL_PATH "Flake path on installed disk" "/mnt/opt/flake" true
    nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
    nds_cfg_ask_path FLAKE_HOST_DIR "Host directory inside flake" "hosts/x86_64-linux" false
    nds_cfg_ask_choice FLAKE_HARDWARE_PLACEMENT "Hardware configuration" "host-dir|etc-nixos|skip" \
        "host-dir=Copy into flake host dir|etc-nixos=Keep in /etc/nixos|skip=Flake handles hardware" "host-dir"
}

installFlake_summary() {
    nds_cfg_summary_row "Install mode" "$(nds_cfg_display_choice "$(nds_cfg_get INSTALL_MODE)" "local=On target|remote=nixos-anywhere")"
    if nds_cfg_is INSTALL_MODE remote; then
        nds_cfg_summary_row "Target host" "$(nds_cfg_get REMOTE_TARGET_IP)"
    fi
    if nds_cfg_is FLAKE_SOURCE remote; then
        nds_cfg_summary_row "Flake (git)" "$(nds_cfg_get FLAKE_REPO_URL)"
    else
        nds_cfg_summary_row "Flake (path)" "$(nds_cfg_get FLAKE_LOCAL_PATH)"
    fi
    nds_cfg_summary_row "Host name" "$(nds_cfg_get FLAKE_HOST)"
}

installFlake_prompt_errors() {
    nds_cfg_section_title "Install mode"
    nds_cfg_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "local"
    if nds_cfg_is INSTALL_MODE remote; then
        nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
    fi

    nds_cfg_section_title "Your flake"
    while ! installFlake_validate &>/dev/null; do
        if nds_cfg_is INSTALL_MODE remote && [[ -z "$(nds_cfg_get REMOTE_TARGET_IP)" ]]; then
            nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
            continue
        fi
        if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" && -z "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
            _installFlake_ask_location
            continue
        fi
        if [[ -z "$(nds_cfg_get FLAKE_HOST)" ]] || ! validate_hostname "$(nds_cfg_get FLAKE_HOST)" 2>/dev/null; then
            nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
            continue
        fi
        break
    done
}

installFlake_validate() {
    if nds_cfg_is INSTALL_MODE remote && [[ -z "$(nds_cfg_get REMOTE_TARGET_IP)" ]]; then
        validation_error "Target host IP is required for remote install"
        return 1
    fi
    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" && -z "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
        validation_error "Flake location (git URL or local path) is required"
        return 1
    fi
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || { validation_error "Host name is required"; return 1; }
    validate_hostname "$(nds_cfg_get FLAKE_HOST)" || {
        validation_error "$(error_msg_hostname)"
        return 1
    }
    return 0
}

NDS_PRESET_PRIORITY=20
NDS_PRESET_DISPLAY="Your flake"
