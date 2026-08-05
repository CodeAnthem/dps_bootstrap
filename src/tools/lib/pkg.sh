#!/usr/bin/env bash
# ==================================================================================================
# NDS - Package binary resolve (PATH or nixpkgs#)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Shared helper — no UI, no domain policy
# ==================================================================================================

# Optional NIX_CONFIG applied when running via nix shell / nix run.
: "${NDS_PKG_NIX_CONFIG:=}"

# Description: Resolve command prefix for a binary via PATH or nixpkgs#attr.
# Arguments:
# - out:   <Nameref> Command array (e.g. (qrencode) or (nix shell … -c qrencode))
# - bin:   <String>  Binary name on PATH
# - attr:  <String|optional> nixpkgs attribute (default: same as bin)
# Returns:
# - 0 when resolvable
nds_pkg_cmd() {
    local -n _nds_pkg_out=$1
    local bin="$2"
    local attr="${3:-$2}"

    if command -v "$bin" &>/dev/null; then
        _nds_pkg_out=("$bin")
        return 0
    fi
    if command -v nix &>/dev/null; then
        _nds_pkg_out=(
            nix --extra-experimental-features "nix-command flakes"
            shell "nixpkgs#${attr}" -c "$bin"
        )
        return 0
    fi
    _nds_pkg_out=()
    return 1
}

# Description: Run binary with args (PATH or nix shell). Honors NDS_PKG_NIX_CONFIG.
# Arguments:
# - bin:  <String> Binary name
# - attr: <String> nixpkgs attribute
# - ...:  args passed to the binary
nds_pkg_run() {
    local bin="$1" attr="$2"
    shift 2
    local -a cmd=()

    nds_pkg_cmd cmd "$bin" "$attr" || return 127
    if [[ -n "${NDS_PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" "$@"
    else
        "${cmd[@]}" "$@"
    fi
}

# Description: Ensure binary is callable (warm nix shell if needed).
# Arguments:
# - bin:  <String> Binary name
# - attr: <String|optional> nixpkgs attribute
nds_pkg_ensure() {
    local bin="$1" attr="${2:-$1}"
    local -a cmd=()

    nds_pkg_cmd cmd "$bin" "$attr" || return 1
    if [[ -n "${NDS_PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" --version >/dev/null 2>&1 \
            || env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" -h >/dev/null 2>&1 \
            || true
    else
        "${cmd[@]}" --version >/dev/null 2>&1 || "${cmd[@]}" -h >/dev/null 2>&1 || true
    fi
    return 0
}
