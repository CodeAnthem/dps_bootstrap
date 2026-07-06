#!/usr/bin/env bash
# Shim — see bootstrap/validators/
# shellcheck source=/dev/null
_sm_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../settingsManager" && pwd)"
_val_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../validators" && pwd)"
source "${_val_dir}/load.sh"
nds_validators_load "$_val_dir"
source "${_sm_dir}/load.sh"
validate_country() {
    local value="$1"
    [[ "$value" =~ ^[A-Za-z]{2}$ ]] || return 1
    nds_country_defaults "${value,,}" &>/dev/null || return 2
    return 0
}
unset _sm_dir _val_dir
