#!/usr/bin/env bash
# ==================================================================================================
# NDS - Per-step VM / live-ISO tests (destructive steps opt-in)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-07-29
# Description:   Run one install concern without the full installFlake menu cycle.
# ==================================================================================================
# Usage (on NixOS live ISO / VM):
#   bash dev/vm-step-test.sh facter
#   bash dev/vm-step-test.sh stage-boot
#   bash dev/vm-step-test.sh list
#
# Env:
#   NDS_FLAKE_ROOT     Flake checkout (default: /mnt/etc/nixos if present)
#   NDS_HOSTNAME       Host name under hosts/… (default: control-toolkit)
#   NDS_FLAKE_HOST_DIR Relative host dir (default: hosts/x86_64-linux)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="${ROOT}/src"
export SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/core/import.sh"
nds_bootstrap_load_libs "$SCRIPT_DIR" || {
    echo "Failed to load NDS libs" >&2
    exit 1
}
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/standalone/git/load.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/standalone/install/load.sh"
nds_standalone_git_load
nds_standalone_install_load
nds_framework_load_remaining || {
    echo "Failed to load install framework" >&2
    exit 1
}

_vmstep_usage() {
    cat <<'EOF'
vm-step-test.sh <step>

Steps:
  list          Show available steps
  facter        Generate + sanitize facter.json under /tmp (no partition)
  sanitize      Sanitize an existing report (path arg or NDS_FACTER_IN)
  stage-boot    git add mounts.nix + boot.nix + facter.json in a flake checkout
  selftest      Run CI self-tests (safe on any host)

These do NOT run full installFlake. Use them on the live ISO to isolate failures.
EOF
}

_vmstep_facter() {
    local dest="/tmp/nds-vm-facter-$$.json"
    echo "==> generating facter -> ${dest}"
    _install_generate_facter_report "$dest"
    echo "==> ok (null-scrub applied)"
    echo "    path: ${dest}"
    echo "    cpu entries:"
    nix --extra-experimental-features 'nix-command flakes' eval --impure --json --expr "
let r = builtins.fromJSON (builtins.readFile \"${dest}\");
in map (c: if c == null then \"null\" else (c.model_name or \"obj\")) (r.hardware.cpu or [])
"
}

_vmstep_sanitize() {
    local src="${1:-${NDS_FACTER_IN:-}}"
    [[ -n "$src" && -f "$src" ]] || {
        echo "Need path: vm-step-test.sh sanitize /path/to/facter.json" >&2
        return 1
    }
    local dest
    dest=$(mktemp --suffix=.json)
    cp "$src" "$dest"
    _install_sanitize_facter_report "$dest"
    echo "sanitized copy: ${dest}"
}

_vmstep_stage_boot() {
    local flake_root="${NDS_FLAKE_ROOT:-}"
    if [[ -z "$flake_root" ]]; then
        if [[ -d /mnt/etc/nixos ]]; then
            flake_root=/mnt/etc/nixos
        elif [[ -d /mnt/opt/flake ]]; then
            flake_root=/mnt/opt/flake
        else
            flake_root=/mnt/etc/nixos
        fi
    fi
    local host_rel="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    local hostname="${NDS_HOSTNAME:-control-toolkit}"
    local host_dir="${flake_root}/${host_rel}/${hostname}"

    [[ -d "$flake_root" ]] || {
        echo "Flake root missing: ${flake_root}" >&2
        return 1
    }
    [[ -d "$host_dir" ]] || {
        echo "Host dir missing: ${host_dir}" >&2
        return 1
    }
    _install_flake_git_stage_install_files "$flake_root" "$host_dir"
    echo "staged install-time files under ${host_dir}"
    git -C "$flake_root" status --short -- "hosts/" || true
}

step="${1:-list}"
case "$step" in
    list|-h|--help) _vmstep_usage ;;
    facter) _vmstep_facter ;;
    sanitize) _vmstep_sanitize "${2:-}" ;;
    stage-boot) _vmstep_stage_boot ;;
    selftest) exec bash "${ROOT}/dev/selftest.sh" ;;
    *)
        echo "Unknown step: ${step}" >&2
        _vmstep_usage
        exit 1
        ;;
esac
