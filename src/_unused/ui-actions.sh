#!/usr/bin/env bash
# Shim — see bootstrap/core/menus/
# shellcheck source=/dev/null
_menus="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core/menus" && pwd)"
source "${_menus}/menu.install-confirm.sh"
source "${_menus}/menu.remote-confirm.sh"
unset _menus
