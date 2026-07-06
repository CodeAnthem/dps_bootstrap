#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install context (single config read per pipeline)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

# Description: Read CONFIG_DATA + NDS_FLAKE_* into NDS_CTX_* globals.
_nixinstall_gather_context() {
    NDS_CTX_DISK=$(nds_config_get "disk" "DISK_TARGET")
    NDS_CTX_DISK_STRATEGY=$(nds_config_get "disk" "DISK_STRATEGY")
    NDS_CTX_DISK_STRATEGY="${NDS_CTX_DISK_STRATEGY:-nds}"
    NDS_CTX_ENCRYPTION=$(nds_config_get "encryption" "ENCRYPTION")
    NDS_CTX_HOSTNAME=$(nds_config_get "network" "NETWORK_HOSTNAME")
    NDS_CTX_REMOTE_UNLOCK=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_UNLOCK")
    NDS_CTX_ENCRYPTION_PASSWORD=$(nds_config_get "encryption" "ENCRYPTION_PASSWORD")
    NDS_CTX_ENCRYPTION_KEY=$(nds_config_get "encryption" "ENCRYPTION_KEY")
    NDS_CTX_KEY_BOOT_DEVICE=$(nds_config_get "encryption" "ENCRYPTION_KEY_BOOT_DEVICE")
    NDS_CTX_KEY_BOOT_FILE=$(nds_config_get "encryption" "ENCRYPTION_KEY_BOOT_FILE")
    NDS_CTX_REMOTE_NETWORK=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_NETWORK")
    NDS_CTX_NETWORK_IP=$(nds_config_get "network" "NETWORK_IP")
    NDS_CTX_REMOTE_PORT=$(nds_config_get "encryption" "ENCRYPTION_REMOTE_PORT")
    [[ -n "$NDS_CTX_REMOTE_PORT" ]] || NDS_CTX_REMOTE_PORT=2222
    NDS_CTX_ADMIN_USER=$(nds_config_get "access" "ACCESS_ADMIN_USER")
    NDS_CTX_ADMIN_USER="${NDS_CTX_ADMIN_USER:-admin}"
    NDS_CTX_SSH_PORT=$(nds_config_get "access" "ACCESS_SSH_PORT")
    NDS_CTX_SSH_PORT="${NDS_CTX_SSH_PORT:-22}"
    NDS_CTX_SSH_PW_AUTH=$(nds_config_get "access" "ACCESS_SSH_PASSWORD_AUTH")
    NDS_CTX_ADMIN_SSH_KEY=$(nds_config_get "access" "ACCESS_ADMIN_SSH_KEY")
    return 0
}

# Description: Extend base context with flake install fields.
_nixinstall_gather_flake_context() {
    _nixinstall_gather_context
    NDS_CTX_FLAKE_SOURCE="${NDS_FLAKE_SOURCE:-$(nds_configurator_config_get "FLAKE_SOURCE")}"
    NDS_CTX_FLAKE_REPO_URL="${NDS_FLAKE_REPO_URL:-$(nds_configurator_config_get "FLAKE_REPO_URL")}"
    NDS_CTX_FLAKE_LOCAL_PATH="${NDS_FLAKE_LOCAL_PATH:-$(nds_configurator_config_get "FLAKE_LOCAL_PATH")}"
    NDS_CTX_FLAKE_INSTALL_PATH="${NDS_FLAKE_INSTALL_PATH:-$(nds_configurator_config_get "FLAKE_INSTALL_PATH")}"
    NDS_CTX_FLAKE_HOST_DIR="${NDS_FLAKE_HOST_DIR:-$(nds_configurator_config_get "FLAKE_HOST_DIR")}"
    NDS_CTX_HW_PLACEMENT="${NDS_HARDWARE_PLACEMENT:-$(nds_configurator_config_get "FLAKE_HARDWARE_PLACEMENT")}"
    NDS_CTX_HW_PLACEMENT="${NDS_CTX_HW_PLACEMENT:-host-dir}"
    NDS_CTX_INSTALL_MODE="${NDS_INSTALL_MODE:-$(nds_configurator_config_get "INSTALL_MODE")}"
    NDS_CTX_INSTALL_MODE="${NDS_CTX_INSTALL_MODE:-local}"
    NDS_CTX_REMOTE_TARGET_IP="${NDS_REMOTE_TARGET_IP:-$(nds_configurator_config_get "REMOTE_TARGET_IP")}"
    if [[ -z "${NDS_CTX_DISK_STRATEGY:-}" || "$NDS_CTX_DISK_STRATEGY" == "nds" ]]; then
        NDS_CTX_DISK_STRATEGY="${NDS_DISK_STRATEGY:-$NDS_CTX_DISK_STRATEGY}"
        NDS_CTX_DISK_STRATEGY="${NDS_CTX_DISK_STRATEGY:-nds}"
    fi
    return 0
}
