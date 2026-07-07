#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install log paths and fetch hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Diag log in /home/nixos (nixos-owned); verbose log published for scp
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

# Description: chown/chmod home log files for the live-ISO nixos user.
# Arguments:
# - user: <String> Target owner (e.g. nixos)
# - paths: <String+> Files to fix
_nds_install_logs_chown_files() {
    local user="$1"
    shift
    local path

    [[ -n "$user" ]] || return 0
    for path in "$@"; do
        [[ -e "$path" ]] || continue
        chown "$user" "$path" 2>/dev/null || true
        chmod 600 "$path" 2>/dev/null || true
    done
}

# Description: Point diag log at /home/nixos and create nixos-owned log files.
nds_install_logs_init() {
    local user diag_home verbose_home

    user=$(nds_install_ssh_user)
    diag_home=$(nds_install_logs_home_diag)
    verbose_home=$(nds_install_logs_home_verbose)
    mkdir -p "/home/${user}"
    : >"$diag_home"
    : >"$verbose_home"
    _nds_install_logs_chown_files "$user" "$diag_home" "$verbose_home"
    export NDS_INSTALL_DIAG_LOG="$diag_home"
}

# Description: Copy verbose install log into /home/nixos; refresh ownership on both logs.
nds_install_logs_publish() {
    local user diag_home verbose_home

    user=$(nds_install_ssh_user)
    diag_home=$(nds_install_logs_home_diag)
    verbose_home=$(nds_install_logs_home_verbose)
    mkdir -p "/home/${user}"

    if [[ -f "${NDS_INSTALL_DETAIL_LOG:-}" \
        && "${NDS_INSTALL_DETAIL_LOG}" != "$verbose_home" ]]; then
        cp "${NDS_INSTALL_DETAIL_LOG}" "$verbose_home"
    fi

    _nds_install_logs_chown_files "$user" "$diag_home" "$verbose_home"
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
