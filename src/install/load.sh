#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install stack loader (explicit order)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-05
# ==================================================================================================

nds_install_load() {
    local install_dir="${1:?install dir}"

    nds_import_file "${SCRIPT_DIR}/install/lib/load.sh" || return 1
    nds_standalone_install_load || return 1
    nds_import_file "${install_dir}/detect.sh" || return 1
    nds_import_file "${install_dir}/nix-store.sh" || return 1
    nds_import_file "${install_dir}/context.sh" || return 1
    nds_import_file "${install_dir}/diagnostics.sh" || return 1
    nds_import_file "${install_dir}/encryption.sh" || return 1
    nds_import_file "${install_dir}/disko.sh" || return 1
    nds_import_file "${install_dir}/access.sh" || return 1
    nds_import_file "${install_dir}/remoteUnlock.sh" || return 1
    nds_import_file "${install_dir}/boot.sh" || return 1
    nds_import_file "${install_dir}/machineFacts.sh" || return 1
    nds_import_file "${install_dir}/hostStructure.sh" || return 1
    nds_import_file "${install_dir}/preflight.sh" || return 1
    nds_import_file "${install_dir}/install.sh" || return 1
    nds_import_file "${install_dir}/verify.sh" || return 1
    nds_import_file "${install_dir}/bundle/load.sh" || return 1
    nds_install_bundle_load "${install_dir}/bundle" || return 1
    nds_import_file "${install_dir}/logs.sh" || return 1
    nds_import_file "${install_dir}/sops.sh" || return 1
    nds_import_file "${install_dir}/partitionTools.sh" || return 1
    nds_import_file "${install_dir}/disk-prep.sh" || return 1
    nds_import_file "${install_dir}/classic-pipeline.sh" || return 1
    nds_import_file "${install_dir}/flake-pipeline.sh" || return 1
    nds_import_file "${install_dir}/logic/install_ctx_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/flake_gate_logic.sh" || return 1
    nds_import_file "${install_dir}/ui/flake_gate_prompts.sh" || return 1
    nds_import_file "${install_dir}/ui/flake_hosts_prompts.sh" || return 1
    nds_import_file "${install_dir}/flake-gate.sh" || return 1
    nds_import_file "${install_dir}/flake-install-pipeline.sh" || return 1
    return 0
}
