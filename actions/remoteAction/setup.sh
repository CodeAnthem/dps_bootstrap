#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action from target flake
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
# Description:   Clone a flake and run its .nds/action.sh if present, else fall back to a flake install
# ==================================================================================================

action_config() {
    nds_configurator_preset_disable quick
    nds_configurator_preset_disable region
    nds_configurator_preset_disable network
    nds_configurator_preset_disable boot
    nds_configurator_preset_disable security
    nds_configurator_preset_disable platform
    nds_configurator_preset_disable installFlake

    nds_configurator_preset_enable remoteAction
    nds_configurator_preset_set_display remoteAction "Remote flake action"
    nds_configurator_preset_set_priority remoteAction 20

    PRESET_CONTEXT="remoteAction"

    nds_configurator_var_declare FLAKE_REPO_URL \
        display="Remote flake Git URL" \
        input=url \
        default="" \
        required=true

    nds_configurator_var_declare FLAKE_INSTALL_PATH \
        display="Flake path on installed disk" \
        input=path \
        default="/mnt/opt/flake" \
        required=true

    nds_configurator_var_declare FLAKE_HOST \
        display="nixosConfigurations host name" \
        input=hostname \
        required=true

    nds_configurator_var_declare FLAKE_HOST_DIR \
        display="Host directory inside flake" \
        input=path \
        default="hosts/x86_64-linux" \
        required=false

    nds_configurator_var_declare HARDWARE_PLACEMENT \
        display="Hardware configuration" \
        input=choice \
        default="host-dir" \
        options="host-dir|etc-nixos|skip"

    PRESET_CONTEXT=""
}

_remoteaction_prepare() {
    local host repo_url install_path host_dir hw_placement disk_strategy
    host=$(nds_configurator_config_get "FLAKE_HOST")
    repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")
    install_path=$(nds_configurator_config_get "FLAKE_INSTALL_PATH")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    hw_placement=$(nds_configurator_config_get "HARDWARE_PLACEMENT")
    disk_strategy=$(nds_config_get "disk" "DISK_STRATEGY")

    nds_configurator_config_set "HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"
    export NDS_FLAKE_SOURCE="remote"
    export NDS_FLAKE_REPO_URL="$repo_url"
    export NDS_FLAKE_INSTALL_PATH="$install_path"
    export NDS_FLAKE_HOST_DIR="$host_dir"
    export NDS_HARDWARE_PLACEMENT="$hw_placement"
    export NDS_DISK_STRATEGY="$disk_strategy"
}

_remoteaction_find_script() {
    local flake_root="$1"
    local candidate

    for candidate in \
        "${flake_root}/.nds/action.sh" \
        "${flake_root}/nds-action/setup.sh" \
        "${flake_root}/.nds/setup.sh"; do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

action_preview() {
    nds_ui_h "Run a custom install action from your flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "flake Git URL, host name, host directory, hardware placement, disk"
    nds_ui_i "plus any extra fields your .nds/action.sh adds"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "clone the flake and load its .nds/action.sh"
    nds_ui_i "run your install script (or fall back to a standard flake install)"
    nds_ui_i "reboot when done"
    nds_ui_b ""
}

action_setup() {
    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12
    _remoteaction_prepare

    local repo_url="${NDS_FLAKE_REPO_URL}"
    local host_dir="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    local probe_dir remote_script
    local disk_strategy disk_target

    step_start "Fetching flake for action probe"
    probe_dir=$(nds_preflight_probe_flake "$repo_url") || exit 14
    step_complete "Flake cloned for probe"

    nds_preflight_apply_disko_strategy "$probe_dir" "${NDS_FLAKE_HOST}" "$host_dir"

    if remote_script=$(_remoteaction_find_script "$probe_dir"); then
        info "Found remote action: $remote_script"
        nds_import_file "$remote_script" || exit 14

        if declare -f remote_action_config &>/dev/null; then
            remote_action_config
            nds_configurator_menu || exit 12
            _remoteaction_prepare
        fi
    else
        warn "No .nds/action.sh found — will use a standard flake install"
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

    nds_install_finish || exit 16
}
