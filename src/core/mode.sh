#!/usr/bin/env bash
# ==================================================================================================
# NDS - Run mode (interactive | unattended)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Global NDS_MODE; features decide their own UI when mode allows
# ==================================================================================================

# interactive | unattended — set by nds_mode_resolve or env
declare -g NDS_MODE="${NDS_MODE:-}"

# Description: True when value is boolean true (true/1, case-insensitive).
nds_mode_env_true() {
    local value="${1:-}"
    [[ "${value,,}" == "true" || "$value" == "1" ]]
}

# Description: Resolve NDS_MODE from env if unset (env only; no settings store).
# Order: NDS_MODE → NDS_UNATTENDED → NDS_AUTO_CONFIRM → interactive.
nds_mode_resolve() {
    if [[ -n "${NDS_MODE:-}" ]]; then
        case "${NDS_MODE}" in
            interactive|unattended) ;;
            *)
                if declare -f error &>/dev/null; then
                    error "NDS_MODE must be interactive or unattended (got: ${NDS_MODE})"
                else
                    printf 'NDS_MODE must be interactive or unattended (got: %s)\n' "$NDS_MODE" >&2
                fi
                return 1
                ;;
        esac
        export NDS_MODE
        return 0
    fi

    if nds_mode_env_true "${NDS_UNATTENDED:-}"; then
        NDS_MODE="unattended"
    elif nds_mode_env_true "${NDS_AUTO_CONFIRM:-}"; then
        NDS_MODE="unattended"
    else
        NDS_MODE="interactive"
    fi
    export NDS_MODE
    return 0
}

# Description: True when global mode is unattended.
nds_mode_is_unattended() {
    [[ "${NDS_MODE:-interactive}" == "unattended" ]]
}

# Description: True when global mode is interactive.
nds_mode_is_interactive() {
    ! nds_mode_is_unattended
}
