#!/usr/bin/env bash
# ==================================================================================================
# NDS - Per-step VM / live-ISO tests (destructive steps opt-in)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-07-08
# Description:   Run one install concern without the full installFlake menu cycle.
# ==================================================================================================
# Usage (on NixOS live ISO / VM):
#   bash scripts/vm-step-test.sh facter
#   bash scripts/vm-step-test.sh stage-boot
#   bash scripts/vm-step-test.sh list
#
# Env:
#   NDS_FLAKE_ROOT     Flake checkout (default: /mnt/opt/flake if present)
#   NDS_HOSTNAME       Host name under hosts/… (default: control-toolkit)
#   NDS_FLAKE_HOST_DIR Relative host dir (default: hosts/x86_64-linux)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="${ROOT}/bootstrap"
export SCRIPT_DIR
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/core/import.sh"
nds_bootstrap_load_libs "$SCRIPT_DIR" || {
    echo "Failed to load NDS libs" >&2
    exit 1
}

_nds_vm_step_usage() {
    cat <<'EOF'
vm-step-test.sh <step>

Steps:
  list          Show available steps
  facter        Generate + sanitize facter.json under /tmp (no partition)
  sanitize      Sanitize an existing report (path arg or NDS_FACTER_IN)
  stage-boot    git add -f nds-boot.nix + facter.json in a flake checkout
  selftest      Run CI self-tests (safe on any host)

These do NOT run full installFlake. Use them on the live ISO to isolate failures.
EOF
}

_nds_vm_step_facter() {
    local dest="/tmp/nds-vm-facter-$$.json"
    echo "==> generating facter -> ${dest}"
    _nixinstall_generate_facter_report "$dest"
    echo "==> ok (null-scrub applied)"
    echo "    path: ${dest}"
    echo "    cpu entries:"
    nix --extra-experimental-features 'nix-command flakes' eval --impure --json --expr "
let r = builtins.fromJSON (builtins.readFile \"${dest}\");
in map (c: if c == null then \"null\" else (c.model_name or \"obj\")) (r.hardware.cpu or [])
"
}

_nds_vm_step_sanitize() {
    local src="${1:-${NDS_FACTER_IN:-}}"
    [[ -n "$src" && -f "$src" ]] || {
        echo "Need path: vm-step-test.sh sanitize /path/to/facter.json" >&2
        return 1
    }
    local dest
    dest=$(mktemp --suffix=.json)
    cp "$src" "$dest"
    _nixinstall_sanitize_facter_report "$dest"
    echo "sanitized copy: ${dest}"
}

_nds_vm_step_stage_boot() {
    local flake_root="${NDS_FLAKE_ROOT:-/mnt/opt/flake}"
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
    _nds_install_flake_git_stage_install_files "$flake_root" "$host_dir"
    echo "staged install-time files under ${host_dir}"
    git -C "$flake_root" status --short -- "hosts/" || true
}

step="${1:-list}"
case "$step" in
    list|-h|--help) _nds_vm_step_usage ;;
    facter) _nds_vm_step_facter ;;
    sanitize) _nds_vm_step_sanitize "${2:-}" ;;
    stage-boot) _nds_vm_step_stage_boot ;;
    selftest) exec bash "${ROOT}/scripts/selftest.sh" ;;
    *)
        echo "Unknown step: ${step}" >&2
        _nds_vm_step_usage
        exit 1
        ;;
esac
