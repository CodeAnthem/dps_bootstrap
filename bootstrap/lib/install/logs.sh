#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install log paths and fetch hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Publish diag/verbose logs to /home/nixos for scp (same ownership model as bundle)
# ==================================================================================================

# Description: Compact diagnostics log in the nixos home directory.
# Returns:
# - <String> path (stdout)
nds_install_logs_home_diag() {
    local user
    user=$(nds_install_ssh_user)
    printf '/home/%s/nds_install_diag.log' "$user"
}

# Description: Verbose nixos-install log in the nixos home directory.
# Returns:
# - <String> path (stdout)
nds_install_logs_home_verbose() {
    local user
    user=$(nds_install_ssh_user)
    printf '/home/%s/nds_install_verbose.log' "$user"
}

# Description: Copy session logs into /home/nixos (chown nixos, mode 600).
nds_install_logs_publish() {
    local user diag_home verbose_home

    user=$(nds_install_ssh_user)
    diag_home=$(nds_install_logs_home_diag)
    verbose_home=$(nds_install_logs_home_verbose)
    mkdir -p "/home/${user}"

    if [[ -f "${NDS_INSTALL_DIAG_LOG:-}" ]]; then
        cp "${NDS_INSTALL_DIAG_LOG}" "$diag_home"
    fi
    if [[ -f "${NDS_INSTALL_DETAIL_LOG:-}" ]]; then
        cp "${NDS_INSTALL_DETAIL_LOG}" "$verbose_home"
    fi

    chown "${user}:${user}" "$diag_home" "$verbose_home" 2>/dev/null || true
    chmod 600 "$diag_home" "$verbose_home" 2>/dev/null || true
}

# Description: Print scp commands to copy install logs to the operator machine.
nds_install_logs_fetch_hints() {
    local user host diag_home verbose_home

    nds_install_logs_publish
    user=$(nds_install_ssh_user)
    host=$(nds_install_bundle_host_ip)
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
