#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action from target flake
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-06
# Description:   Clone a flake and run its .nds/action.sh if present, else fall back to a flake install
# ==================================================================================================

action_presets() {
    printf '%s\n' remoteAction boot disk encryption platform
}

action_config() {
    nds_configurator_preset_set_display remoteAction "Remote flake action"
    nds_configurator_preset_set_priority remoteAction 20
    nds_configurator_preset_set_priority boot 21
    nds_configurator_preset_set_priority disk 22
    nds_configurator_preset_set_priority encryption 23
    nds_configurator_preset_set_priority platform 24
}

# Optional: extra preset dirs from env (colon-separated paths).
action_presets_paths() {
    [[ -n "${NDS_PRESET_EXTRA_DIR:-}" ]] && printf '%s\n' "$NDS_PRESET_EXTRA_DIR"
    [[ -n "${NDS_PRESET_EXTRA_PATHS:-}" ]] && tr ':' '\n' <<< "$NDS_PRESET_EXTRA_PATHS"
}

action_preview() {
    nds_ui_h "Run a custom install action from your flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "flake Git URL, host name, host directory, hardware placement, disk"
    nds_ui_i "plus any extra fields from your flake's .nds/presets/"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "clone the flake and inject custom preset hooks from .nds/"
    nds_ui_i "run your install script (or fall back to a standard flake install)"
    nds_ui_i "reboot when done"
    nds_ui_b ""
}

action_setup() {
    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu_or_skip || exit 12
    nds_flake_prepare remote
    nds_git_ensure_access "$(nds_configurator_config_get FLAKE_REPO_URL)" || exit 14

    local repo_url="${NDS_FLAKE_REPO_URL}"
    local host_dir="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    local probe_dir remote_script injected=0
    local disk_strategy disk_target

    step_start "Fetching flake for action probe"
    probe_dir=$(nds_preflight_probe_flake "$repo_url") || exit 14
    step_complete "Flake cloned for probe"
    export NDS_FLAKE_PROBE_DIR="$probe_dir"

    nds_preset_inject_from_flake "$probe_dir" || true
    injected=$NDS_PRESET_INJECT_COUNT
    if [[ "${injected:-0}" -gt 0 ]]; then
        info "Loaded ${injected} custom preset(s) from flake .nds/"
    fi

    nds_preflight_apply_disko_strategy "$probe_dir" "${NDS_FLAKE_HOST}" "$host_dir"

    step_start "Verifying git input access"
    nds_git_ensure_flake_closure_access "$probe_dir" "$repo_url" || exit 14
    step_complete "Git input access OK"

    if remote_script=$(nds_flake_find_action_script "$probe_dir"); then
        info "Found remote action: $remote_script"
        nds_import_file "$remote_script" || exit 14

        if declare -f remote_action_config &>/dev/null; then
            remote_action_config
            nds_configurator_menu_or_skip || exit 12
            nds_flake_prepare remote
        fi
    else
        warn "No .nds/action.sh found — using role discovery + scaffolding"
        if nds_flake_scaffold_interactive "$probe_dir" "$(basename "$host_dir")"; then
            nds_flake_prepare
        else
            warn "No profiles/ found in flake — falling back to a standard flake install"
        fi
    fi

    disk_strategy="$(nds_config_get "disk" "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_config_get "disk" "DISK_TARGET")"

    nds_preflight_install "$disk_target" "$repo_url" || exit 11
    nds_action_confirm_install "$disk_target" "$disk_strategy" || exit 13

    if [[ -n "${remote_script:-}" ]]; then
        if declare -f remote_action_run &>/dev/null; then
            nds_install_log "remoteAction: running ${remote_script}"
            remote_action_run || exit 15
        elif declare -f action_setup &>/dev/null; then
            nds_install_log "remoteAction: running action_setup from ${remote_script}"
            action_setup || exit 15
        else
            error "Remote action must define remote_action_run or action_setup"
            exit 14
        fi
    else
        nds_install_log "remoteAction: fallback to flake install"
        nds_nixos_install_flake || exit 15
    fi

    export NDS_GIT_INSTALL_SUCCEEDED=true
    nds_git_access_cleanup_success
    nds_install_finish || exit 16
}
