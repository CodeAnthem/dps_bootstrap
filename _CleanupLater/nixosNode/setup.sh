#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - NixOS Node Action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-17 | Modified: 2026-06-27
# Description:   Install dps_swarm cluster nodes from live ISO via flake
# ==================================================================================================

# =============================================================================
# ACTION CONFIGURATION
# =============================================================================
action_config() {
    PRESET_CONTEXT="nixosNode"

    nds_configurator_preset_set_display "nixosNode" "Cluster Node"
    nds_configurator_preset_set_priority "nixosNode" 50

    nds_configurator_var_declare FLAKE_REPO_URL \
        display="dps_swarm Git URL" \
        input=url \
        default="git+ssh://git@github.com/CodeAnthem/dps_swarm.git" \
        required=true

    nds_configurator_var_declare FLAKE_INSTALL_PATH \
        display="Flake checkout on target disk" \
        input=path \
        default="/mnt/opt/dps_swarm" \
        required=true

    nds_configurator_var_declare NODE_ROLE \
        display="Cluster role" \
        input=choice \
        default="worker" \
        options="gateway|worker|gpu-worker|encrypted-worker|control-toolkit" \
        required=true

    PRESET_CONTEXT=""

    nds_configurator_config_set "ENCRYPTION" "true"
    nds_configurator_config_set "REMOTE_UNLOCK" "false"
    nds_configurator_config_set "NETWORK_METHOD" "static"
}

# Map role preset to flake host name (must match hosts/x86_64-linux/<name>)
_nixosnode_resolve_host() {
    local role hostname
    role=$(nds_configurator_config_get "NODE_ROLE")
    hostname=$(nds_configurator_config_get "HOSTNAME")

    if [[ -n "$hostname" ]]; then
        echo "$hostname"
        return 0
    fi

    case "$role" in
        gateway) echo "gateway-01" ;;
        gpu-worker) echo "gpu-worker-01" ;;
        encrypted-worker) echo "encrypted-worker" ;;
        control-toolkit) echo "control-toolkit" ;;
        worker) echo "worker-01" ;;
        *) error "Unknown NODE_ROLE: $role" ;;
    esac
}

_nixosnode_apply_role_defaults() {
    local role
    role=$(nds_configurator_config_get "NODE_ROLE")

    case "$role" in
        encrypted-worker)
            nds_configurator_config_set "ENCRYPTION" "true"
            nds_configurator_config_set "REMOTE_UNLOCK" "true"
            ;;
        gateway|gpu-worker|worker|control-toolkit)
            nds_configurator_config_set "ENCRYPTION" "true"
            ;;
    esac
}

_nixosnode_prepare_host_identity() {
    local host
    _nixosnode_apply_role_defaults
    host=$(_nixosnode_resolve_host)
    nds_configurator_config_set "HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"
    NDS_FLAKE_REPO_URL="$(nds_configurator_config_get "FLAKE_REPO_URL")"
    export NDS_FLAKE_REPO_URL
    NDS_FLAKE_INSTALL_PATH="$(nds_configurator_config_get "FLAKE_INSTALL_PATH")"
    export NDS_FLAKE_INSTALL_PATH
    log "Flake host selected: ${NDS_FLAKE_INSTALL_PATH}#${host}"
}

action_show_completion() {
    console ""
    console "Cluster node installed: ${NDS_FLAKE_HOST:-unknown}"
    console "  Flake: ${NDS_FLAKE_ROOT:-unknown}"
    console ""
    console "Next steps:"
    console "  1. Back up install secrets (LUKS key in runtime dir if encrypted)"
    console "  2. Encrypt LUKS key into sops (luks/root_key) before production use"
    console "  3. Reboot into installed system"
    console ""
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================
action_setup() {
    console "Install a dps_swarm cluster node from the Thundercast leaf flake."
    console "  • Disk layout + optional LUKS + optional remote unlock"
    console "  • hardware-configuration.nix → host dir (gitignored)"
    console "  • nixos-install --flake <dps_swarm>#<host>"

    nds_askUserToProceed "Ready to configure?" || exit 130

    if ! nds_configurator_validate_all; then
        nds_configurator_prompt_errors
        nds_configurator_validate_all || exit 11
    fi

    nds_configurator_menu || exit 12
    _nixosnode_prepare_host_identity

    nds_askUserToProceed "Install ${NDS_FLAKE_HOST}? This will erase the target disk." || exit 13

    new_section
    section_header "NixOS Installation"
    nds_nixos_install_flake || exit 15

    new_section
    action_show_completion
    nds_askUserToProceed "Reboot now?" && reboot
}
