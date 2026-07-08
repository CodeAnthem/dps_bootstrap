#!/usr/bin/env bash
# ==================================================================================================
# NDS - Pull flake updates and switch (deploy-key aware)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-07-08
# Description:   Fetch origin, fast-forward (or rebase with local identity), nixos-rebuild switch.
#                Uses /root/.ssh/nds-git-ssh when present. Install-time host facts must stay
#                untracked/gitignored — this tool refuses divergent local commits.
# Env:
#   NDS_FLAKE_ROOT   Flake root (default /etc/nixos)
#   NDS_FLAKE_HOST   nixosConfigurations attr (default: hostname -s)
#   NDS_FLAKE_REF    Remote ref (default origin/main)
# ==================================================================================================
set -euo pipefail

FLAKE_ROOT="${NDS_FLAKE_ROOT:-/etc/nixos}"
HOST_NAME="${NDS_FLAKE_HOST:-$(hostname -s 2>/dev/null || echo nixos)}"
REMOTE_REF="${NDS_FLAKE_REF:-origin/main}"
WRAP="${NDS_GIT_SSH_WRAPPER:-/root/.ssh/nds-git-ssh}"

_nds_switch_die() {
    echo "nds-switch: $*" >&2
    exit 1
}

_nds_switch_info() {
    echo "nds-switch: $*"
}

[[ -d "$FLAKE_ROOT" ]] || _nds_switch_die "flake root missing: ${FLAKE_ROOT}"
[[ -d "${FLAKE_ROOT}/.git" ]] || _nds_switch_die "not a git checkout: ${FLAKE_ROOT}"

if [[ -x "$WRAP" ]]; then
    export GIT_SSH_COMMAND="$WRAP"
fi

cd "$FLAKE_ROOT"

# Local identity only for this repo (rebase / amend never needed for clean installs)
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

# Refuse local commits that would force merge/rebase games (install must not create these)
ahead=$(git rev-list --count "${REMOTE_REF}..HEAD" 2>/dev/null || echo 0)
behind=$(git rev-list --count "HEAD..${REMOTE_REF}" 2>/dev/null || echo 0)

if [[ "${ahead:-0}" -gt 0 ]]; then
    _nds_switch_die "local branch is ahead of ${REMOTE_REF} by ${ahead} commit(s).
Install-time host facts (facter.json, nds-boot.nix) must stay untracked/gitignored — do not commit them.
To drop local-only commits and match remote:  git reset --hard ${REMOTE_REF}
(Keep host facts as untracked files; restore from backup if reset removes tracked paths you need.)"
fi

if [[ "${behind:-0}" -eq 0 ]]; then
    _nds_switch_info "already up to date with ${REMOTE_REF}"
else
    _nds_switch_info "fast-forward ${behind} commit(s) from ${REMOTE_REF}"
    # Move aside untracked host facts that would block checkout of newly tracked remote files
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

    # Restore parked files only when remote did not introduce the same path
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
