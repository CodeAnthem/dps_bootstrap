#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install stack loader (explicit order)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-07
# ==================================================================================================

nds_install_load() {
    local install_dir="${1:?install dir}"

    nds_import_file "${install_dir}/context.sh" || return 1
    nds_import_file "${install_dir}/disk.sh" || return 1
    nds_import_file "${install_dir}/filesystem.sh" || return 1
    nds_import_file "${install_dir}/encryption.sh" || return 1
    nds_import_file "${install_dir}/disko.sh" || return 1
    nds_import_file "${install_dir}/access.sh" || return 1
    nds_import_file "${install_dir}/remoteUnlock.sh" || return 1
    nds_import_file "${install_dir}/secrets.sh" || return 1
    nds_import_file "${install_dir}/boot.sh" || return 1
    nds_import_file "${install_dir}/machineFacts.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/tools/nix/store.sh" || return 1
    nds_import_file "${install_dir}/preflight.sh" || return 1
    nds_import_file "${install_dir}/install.sh" || return 1
    nds_import_file "${install_dir}/verify.sh" || return 1
    nds_import_file "${install_dir}/bundle/load.sh" || return 1
    nds_install_bundle_load "${install_dir}/bundle" || return 1
    nds_import_file "${install_dir}/sops.sh" || return 1
    nds_import_file "${install_dir}/partitionTools.sh" || return 1
    nds_import_file "${install_dir}/disk-prep.sh" || return 1
    return 0
}
