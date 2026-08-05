#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install context logic (AA-oriented helpers)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Fill config AA from install context (no TTY)
# ==================================================================================================

# Description: Ensure install context is gathered; copy DISK/BOOT/ENCRYPTION* into cfg AA.
# Arguments:
# - cfg: <Nameref> Config AA
nds_install_ctx_logic_fill_aa() {
    local -n _i_cfg=$1
    nds_install_ctx_ensure
    local k
    for k in DISK DISK_STRATEGY DISK_FS_TYPE DISK_SWAP_SIZE_MIB SEPARATE_HOME HOME_SIZE \
        ENCRYPTION ENCRYPTION_PASSWORD ENCRYPTION_KEY BOOT_LOADER BOOT_UEFI_MODE \
        FLAKE_REPO_URL FLAKE_LOCAL_PATH FLAKE_HOST INSTALL_MODE REMOTE_TARGET_IP; do
        local var="NDS_CTX_${k}"
        [[ -n "${!var+x}" ]] || continue
        case "$k" in
            DISK) _i_cfg[DISK_TARGET]="${!var}" ;;
            SEPARATE_HOME) _i_cfg[DISK_SEPARATE_HOME]="${!var}" ;;
            *) _i_cfg["$k"]="${!var}" ;;
        esac
    done
    return 0
}
