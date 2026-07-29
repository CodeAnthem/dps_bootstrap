#!/usr/bin/env bash
# ==================================================================================================
# NDS - Skip variable registry
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Self-registering skip vars; main calls nds_skip_all for --auto-confirm
# ==================================================================================================

declare -ga _NDS_SKIP_REGISTRY=()

# Description: Register a skip variable name so nds_skip_all can set it.
# Call this once per skip gate, next to the nds_skip_menu call that uses the var.
# Arguments:
# - var: <String> Variable name (e.g. NDS_INSTALL_CONFIRM_SKIP)
nds_skip_register() {
    local var="$1"
    [[ " ${_NDS_SKIP_REGISTRY[*]} " == *" $var "* ]] || _NDS_SKIP_REGISTRY+=("$var")
}

# Description: Set all registered skip vars and NDS_AUTO_CONFIRM (--auto-confirm).
nds_skip_all() {
    local var
    for var in "${_NDS_SKIP_REGISTRY[@]}"; do
        export "$var"=true
    done
    export NDS_AUTO_CONFIRM=true
}

# Description: Skip an interactive menu when its NDS_*_SKIP flag or NDS_AUTO_CONFIRM is set.
# Arguments:
# - skip_var: <String> Name of the skip env var (e.g. NDS_INSTALL_CONFIRM_SKIP)
# Returns:
# - 0 when the step should be skipped, 1 when the menu should run
nds_skip_menu() {
    local skip_var="${1:-}"
    nds_env_is_true "${NDS_AUTO_CONFIRM:-false}" && return 0
    [[ -n "$skip_var" ]] && nds_env_is_true "${!skip_var:-false}" && return 0
    return 1
}
