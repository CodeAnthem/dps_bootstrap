#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH environment
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Non-interactive SSH env for git and nix fetches
# ==================================================================================================

# Description: GIT_SSH_COMMAND and related env for non-interactive git/nix fetches.
_nds_git_ssh_env() {
    local key_path identity_args=()
    local -a keys=()

    mapfile -t keys < <(nds_git_keys_list 2>/dev/null || true)
    if [[ ${#keys[@]} -eq 0 ]]; then
        key_path="$(nds_git_session_key_path 2>/dev/null || true)"
        [[ -n "$key_path" && -f "$key_path" ]] && keys=("$key_path")
    fi
    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" ]] || continue
        identity_args+=(-i "$key_path")
    done
    if [[ ${#identity_args[@]} -gt 0 ]]; then
        identity_args+=(-o IdentitiesOnly=yes)
    fi
    printf '%s\n' \
        "GIT_TERMINAL_PROMPT=0" \
        "GIT_SSH_COMMAND=ssh ${identity_args[*]} -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
}

# Description: Environment for nix/git fetches during flake eval and nixos-install.
# Arguments:
# - out: <Array> Nameref to receive VAR=value pairs for env(1)
nds_git_export_nix_env() {
    local -n _out=$1
    _out=()
    while IFS= read -r line; do _out+=("$line"); done < <(_nds_git_ssh_env)
}
