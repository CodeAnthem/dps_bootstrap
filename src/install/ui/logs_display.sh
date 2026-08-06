#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install UI: log fetch hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

# Description: Print scp commands to copy install logs to the operator machine.
nds_install_logs_fetch_hints() {
    local user host diag_home verbose_home

    declare -f nds_install_logs_publish &>/dev/null && nds_install_logs_publish
    user=$(nds_install_ssh_user)
    host=$(nds_bundle_host_ip)
    diag_home=$(nds_install_logs_home_diag)
    verbose_home=$(nds_install_logs_home_verbose)
    [[ -n "$host" ]] || return 0

    nds_ui_b "Copy logs from your local machine:"
    nds_ui_i "Diagnostics (compact, no nix build spam):"
    nds_ui_i "  scp ${user}@${host}:${diag_home} ./nds_install_diag.log"
    nds_ui_i "Verbose (full nixos-install output):"
    nds_ui_i "  scp ${user}@${host}:${verbose_home} ./nds_install_verbose.log"
    nds_ui_b ""
}
