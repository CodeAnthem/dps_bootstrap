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
    nds_import_file "${install_dir}/logic/detect_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/nix_store_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/context_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/diagnostics_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/encryption_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/disko_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/access_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/remote_unlock_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/boot_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/machine_facts_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/host_structure_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/preflight_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/install_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/verify_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/logs_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/sops_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/partition_tools_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/disk_prep_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/classic_pipeline_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/flake_pipeline_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/flake_gate_logic.sh" || return 1
    nds_import_file "${install_dir}/logic/flake_install_pipeline_logic.sh" || return 1
    nds_import_file "${install_dir}/ui/flake_gate_prompts.sh" || return 1
    nds_import_file "${install_dir}/ui/flake_hosts_prompts.sh" || return 1
    nds_import_file "${install_dir}/ui/flake_scaffold_prompts.sh" || return 1
    nds_import_file "${install_dir}/ui/encryption_prompts.sh" || return 1
    nds_import_file "${install_dir}/ui/flake_gate_flow.sh" || return 1
    return 0
}
