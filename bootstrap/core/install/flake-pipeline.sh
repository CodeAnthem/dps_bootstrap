#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake install pipeline (action-level workflow)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   installFlake action steps — uses tools/flake helpers + tools/git
# ==================================================================================================

# Description: Prepare flake env and verify git access to all flake inputs.
# Arguments:
# - source: <String|optional> "remote" | "local" override for nds_flake_prepare
nds_flake_install_prepare_and_verify() {
    local source="${1:-}"
    local host probe_dir local_path repo_url

    nds_flake_prepare "$source"
    repo_url="$(nds_configurator_config_get FLAKE_REPO_URL)"
    nds_git_ensure_access "$repo_url" || return 1
    nds_flake_detect_disko

    host="$(nds_configurator_config_get FLAKE_HOST)"
    local_path="$(nds_configurator_config_get FLAKE_LOCAL_PATH)"
    if [[ -n "$local_path" && -d "$local_path" ]]; then
        probe_dir="$local_path"
    elif [[ -d "${NDS_RUNTIME_DIR}/flake_probe" ]]; then
        probe_dir="${NDS_RUNTIME_DIR}/flake_probe"
    fi

    if [[ -n "${probe_dir:-}" ]]; then
        section_header "Verifying flake access"
        nds_git_ensure_flake_closure_access "$probe_dir" "$repo_url" || return 1
    fi
    return 0
}

# Description: Preflight + confirm screen before flake install runs.
nds_flake_install_confirm() {
    local disk_strategy disk_target repo_url install_mode target_ip
    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"
    repo_url="$(nds_configurator_config_get FLAKE_REPO_URL)"
    install_mode="$(nds_configurator_config_get INSTALL_MODE)"
    install_mode="${install_mode:-local}"
    target_ip="$(nds_configurator_config_get REMOTE_TARGET_IP)"

    if [[ "$install_mode" == "remote" ]]; then
        nds_preflight_remote_install "$target_ip" "$repo_url" || return 1
        nds_action_confirm_remote_install "$target_ip" || return 1
    else
        nds_preflight_install "$disk_target" "$repo_url" || return 1
        nds_action_confirm_install "$disk_target" "$disk_strategy" || return 1
    fi
    return 0
}
