#!/usr/bin/env bash
# ==================================================================================================
# NDS - ShellCheck runner
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Install a pinned ShellCheck release (if needed) and lint NDS shell scripts.
#                Used locally (WSL/Linux/macOS) and in GitHub Actions.
# ==================================================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.10.0}"
readonly SHELLCHECK_VERSION

CACHE_ROOT="${XDG_CACHE_HOME:-${HOME}/.cache}/nds-shellcheck"
readonly CACHE_ROOT

SHELLCHECK_BIN=""

usage() {
    cat <<'EOF'
Usage: scripts/shellcheck.sh [options]

Install ShellCheck (pinned release) when missing, then lint bootstrap/ and actions/ scripts.

Options:
  -h, --help          Show this help
  --version VER       ShellCheck release (default: 0.10.0)
  --list              Print script paths and exit
  --install-only      Install ShellCheck binary, do not lint

Environment:
  SHELLCHECK_BIN      Use this binary instead of cache/PATH lookup
  NDS_SHELLCHECK_USE_SYSTEM=1
                      Prefer shellcheck from PATH when present

Exit code: 0 on success, non-zero if ShellCheck reports issues.
EOF
}

_nds_shellcheck_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}:${arch}" in
        Linux:x86_64) echo "linux.x86_64" ;;
        Linux:aarch64 | Linux:arm64) echo "linux.aarch64" ;;
        Darwin:x86_64) echo "darwin.x86_64" ;;
        Darwin:arm64) echo "darwin.aarch64" ;;
        *)
            echo "Unsupported platform: ${os} ${arch}" >&2
            return 1
            ;;
    esac
}

_nds_shellcheck_collect_scripts() {
    mapfile -t _NDS_LINT_SCRIPTS < <(
        find "${ROOT}/bootstrap" "${ROOT}/actions" -name '*.sh' \
            ! -path '*/_CleanupLater/*' \
            ! -path '*/setup_old.sh' \
            ! -path '*/deployTools/*' \
            ! -path '*/tests/*' \
            | sort
    )
    _NDS_LINT_SCRIPTS+=("${ROOT}/start.sh")
}

_nds_shellcheck_install() {
    local platform archive extract_dir url
    platform="$(_nds_shellcheck_platform)"
    extract_dir="${CACHE_ROOT}/${SHELLCHECK_VERSION}"
    archive="${CACHE_ROOT}/shellcheck-v${SHELLCHECK_VERSION}.${platform}.tar.xz"
    url="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${platform}.tar.xz"

    mkdir -p "${CACHE_ROOT}"

    if [[ ! -x "${extract_dir}/shellcheck" ]]; then
        echo "Installing ShellCheck ${SHELLCHECK_VERSION} (${platform}) → ${extract_dir}" >&2
        curl -fsSL "${url}" -o "${archive}"
        rm -rf "${extract_dir}"
        mkdir -p "${extract_dir}"
        tar -xJf "${archive}" -C "${extract_dir}" --strip-components=1 --no-same-owner
        rm -f "${archive}"
    fi

    SHELLCHECK_BIN="${extract_dir}/shellcheck"
}

_nds_shellcheck_resolve_bin() {
    if [[ -n "${SHELLCHECK_BIN:-}" && -x "${SHELLCHECK_BIN}" ]]; then
        return 0
    fi

    if [[ -n "${SHELLCHECK_BIN:-}" ]]; then
        echo "SHELLCHECK_BIN is set but not executable: ${SHELLCHECK_BIN}" >&2
        return 1
    fi

    if [[ "${NDS_SHELLCHECK_USE_SYSTEM:-}" == "1" ]] && command -v shellcheck &>/dev/null; then
        SHELLCHECK_BIN="$(command -v shellcheck)"
        return 0
    fi

    local cached="${CACHE_ROOT}/${SHELLCHECK_VERSION}/shellcheck"
    if [[ -x "${cached}" ]]; then
        SHELLCHECK_BIN="${cached}"
        return 0
    fi

    _nds_shellcheck_install
}

_nds_shellcheck_run() {
    local install_only=false
    local list_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            --version)
                SHELLCHECK_VERSION="$2"
                shift 2
                ;;
            --install-only)
                install_only=true
                shift
                ;;
            --list)
                list_only=true
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 2
                ;;
        esac
    done

    _nds_shellcheck_resolve_bin
    "${SHELLCHECK_BIN}" --version

    if [[ "$install_only" == true ]]; then
        echo "ShellCheck ready: ${SHELLCHECK_BIN}" >&2
        exit 0
    fi

    _nds_shellcheck_collect_scripts

    if [[ "$list_only" == true ]]; then
        printf '%s\n' "${_NDS_LINT_SCRIPTS[@]}"
        exit 0
    fi

    echo "Linting ${#_NDS_LINT_SCRIPTS[@]} scripts (severity: warning)…" >&2
    "${SHELLCHECK_BIN}" -S warning --rcfile="${ROOT}/.shellcheckrc" "${_NDS_LINT_SCRIPTS[@]}"
}

_nds_shellcheck_run "$@"
