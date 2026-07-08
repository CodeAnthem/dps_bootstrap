#!/usr/bin/env bash
# ==================================================================================================
# NDS - Pull flake updates and switch (deploy-key aware)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-07-08
# Description:   Fetch origin, fast-forward, nixos-rebuild switch.
#                --self-update refreshes this script + nds-git-ssh from dps_bootstrap main
#                into /root/.nds/bin (no full reinstall).
# Env:
#   NDS_FLAKE_ROOT   Flake root (default /etc/nixos)
#   NDS_FLAKE_HOST   nixosConfigurations attr (default: hostname -s)
#   NDS_FLAKE_REF    Remote ref (default origin/main)
#   NDS_BOOTSTRAP_RAW_BASE  Raw GitHub base for self-update (optional)
# ==================================================================================================
set -euo pipefail

FLAKE_ROOT="${NDS_FLAKE_ROOT:-/etc/nixos}"
HOST_NAME="${NDS_FLAKE_HOST:-$(hostname -s 2>/dev/null || echo nixos)}"
REMOTE_REF="${NDS_FLAKE_REF:-origin/main}"
WRAP="${NDS_GIT_SSH_WRAPPER:-}"
NDS_BIN_DIR="${NDS_BIN_DIR:-/root/.nds/bin}"
RAW_BASE="${NDS_BOOTSTRAP_RAW_BASE:-https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/bootstrap/tools/git}"

_nds_switch_die() {
    echo "nds-switch: $*" >&2
    exit 1
}

_nds_switch_info() {
    echo "nds-switch: $*"
}

_nds_switch_resolve_wrap() {
    if [[ -n "$WRAP" && -x "$WRAP" ]]; then
        return 0
    fi
    if [[ -x "${NDS_BIN_DIR}/nds-git-ssh" ]]; then
        WRAP="${NDS_BIN_DIR}/nds-git-ssh"
    elif [[ -x /root/.ssh/nds-git-ssh ]]; then
        WRAP=/root/.ssh/nds-git-ssh
    elif command -v nds-git-ssh &>/dev/null; then
        WRAP="$(command -v nds-git-ssh)"
    else
        WRAP=""
    fi
}

# Description: Download latest helpers from dps_bootstrap into /root/.nds/bin.
_nds_switch_self_update() {
    local dest="$NDS_BIN_DIR"
    mkdir -p "$dest"
    _nds_switch_info "self-update -> ${dest}"
    curl -fsSL "${RAW_BASE}/nds-switch.sh" -o "${dest}/nds-switch.tmp" \
        || _nds_switch_die "failed to download nds-switch.sh"
    curl -fsSL "${RAW_BASE}/nds-git-ssh.sh" -o "${dest}/nds-git-ssh.tmp" \
        || _nds_switch_die "failed to download nds-git-ssh.sh"
    chmod 755 "${dest}/nds-switch.tmp" "${dest}/nds-git-ssh.tmp"
    mv -f "${dest}/nds-switch.tmp" "${dest}/nds-switch"
    mv -f "${dest}/nds-git-ssh.tmp" "${dest}/nds-git-ssh"
    # Keep ISO/install copy in sync when present
    if [[ -d /root/.ssh ]]; then
        cp -f "${dest}/nds-git-ssh" /root/.ssh/nds-git-ssh
        chmod 755 /root/.ssh/nds-git-ssh
    fi
    _nds_switch_info "updated. Put ${dest} first on PATH (extraInit already prefers it after rebuild)."
    _nds_switch_info "run now: ${dest}/nds-switch"
    exit 0
}

if [[ "${1:-}" == "--self-update" || "${1:-}" == "self-update" ]]; then
    _nds_switch_self_update
fi

[[ -d "$FLAKE_ROOT" ]] || _nds_switch_die "flake root missing: ${FLAKE_ROOT}"
[[ -d "${FLAKE_ROOT}/.git" ]] || _nds_switch_die "not a git checkout: ${FLAKE_ROOT}"

_nds_switch_resolve_wrap
if [[ -n "$WRAP" && -x "$WRAP" ]]; then
    export GIT_SSH_COMMAND="$WRAP"
fi

cd "$FLAKE_ROOT"

if [[ -z "$(git config --local user.email 2>/dev/null || true)" ]]; then
    git config --local user.email "nds@$(hostname -s 2>/dev/null || echo host)"
fi
if [[ -z "$(git config --local user.name 2>/dev/null || true)" ]]; then
    git config --local user.name "NDS"
fi

if git rev-parse --is-shallow-repository 2>/dev/null | grep -qx true; then
    _nds_switch_info "unshallowing clone for updates"
    git fetch --unshallow origin 2>/dev/null || git fetch origin
else
    git fetch origin
fi

ahead=$(git rev-list --count "${REMOTE_REF}..HEAD" 2>/dev/null || echo 0)
behind=$(git rev-list --count "HEAD..${REMOTE_REF}" 2>/dev/null || echo 0)

if [[ "${ahead:-0}" -gt 0 ]]; then
    _nds_switch_die "local branch is ahead of ${REMOTE_REF} by ${ahead} commit(s).
Install-time host facts (facter.json, nds-boot.nix, machine.nix) must stay untracked/gitignored.
To match remote:  git reset --hard ${REMOTE_REF}
(Keep host facts as untracked files.)"
fi

if [[ "${behind:-0}" -eq 0 ]]; then
    _nds_switch_info "already up to date with ${REMOTE_REF}"
else
    _nds_switch_info "fast-forward ${behind} commit(s) from ${REMOTE_REF}"
    host_dir=$(find hosts -mindepth 2 -maxdepth 2 -type d -name "$HOST_NAME" 2>/dev/null | head -1 || true)
    stash_dir=""
    if [[ -n "$host_dir" ]]; then
        for f in facter.json nds-boot.nix machine.nix hardware-configuration.nix; do
            [[ -f "${host_dir}/${f}" ]] || continue
            if git check-ignore -q "${host_dir}/${f}" 2>/dev/null \
                || ! git ls-files --error-unmatch "${host_dir}/${f}" &>/dev/null; then
                stash_dir="${stash_dir:-$(mktemp -d /tmp/nds-switch-hostfacts.XXXXXX)}"
                mkdir -p "${stash_dir}/${host_dir}"
                mv "${host_dir}/${f}" "${stash_dir}/${host_dir}/"
                _nds_switch_info "parked ${host_dir}/${f} -> ${stash_dir}"
            fi
        done
    fi

    branch="${REMOTE_REF#origin/}"
    if ! git pull --ff-only origin "$branch"; then
        [[ -n "$stash_dir" ]] && _nds_switch_info "host facts parked at ${stash_dir}"
        _nds_switch_die "fast-forward failed — resolve manually in ${FLAKE_ROOT}"
    fi

    if [[ -n "$stash_dir" && -d "$stash_dir" ]]; then
        while IFS= read -r -d '' parked; do
            rel="${parked#"${stash_dir}/"}"
            if [[ -e "${FLAKE_ROOT}/${rel}" ]]; then
                _nds_switch_info "keeping remote ${rel}; parked copy at ${parked}"
            else
                mkdir -p "$(dirname "${FLAKE_ROOT}/${rel}")"
                mv "$parked" "${FLAKE_ROOT}/${rel}"
                _nds_switch_info "restored ${rel}"
            fi
        done < <(find "$stash_dir" -type f -print0 2>/dev/null)
        rm -rf "$stash_dir"
    fi
fi

_nds_switch_info "nixos-rebuild switch --flake ${FLAKE_ROOT}#${HOST_NAME}"
exec nixos-rebuild switch --flake "${FLAKE_ROOT}#${HOST_NAME}"
