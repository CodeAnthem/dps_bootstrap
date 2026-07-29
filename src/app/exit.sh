#!/usr/bin/env bash
# ==================================================================================================
# NDS - App exit and trap helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Exit hooks, fatal handling, and trap-safe shutdown output
# ==================================================================================================

declare -g fatal_message=""

# Description: Store a fatal message and terminate with the app fatal exit code.
crash() {
    fatal_message="$1"
    exit 200
}

# Description: Run registered hook function by hook key when present.
_app_call_hook() {
    local hookName="$1"
    shift
    local hookFunction="${NDS_HOOK_FUNCTIONS[$hookName]}"
    [[ -n "$hookFunction" ]] || { error "Hook '$hookName' not found"; return 1; }
    declare -f "$hookFunction" &>/dev/null && { "$hookFunction" "$@"; return 0; }
    return 1
}

# Description: Default EXIT trap handler for the app entrypoint.
_app_stop_handler() {
    local exit_code=$?
    local exit_msg=""
    exit_msg=$(_app_call_hook "exit_msg" "$exit_code" || true)

    [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]] && return 0

    if [[ -n "$exit_msg" ]]; then
        console "$exit_msg"
    else
        case "${exit_code}" in
            0) success "Script completed successfully" ;;
            130) warn "Script aborted by user" ;;
            200) fatal "Internal error! - ${fatal_message:-}" ;;
            *) warn "Script failed with exit code: $exit_code" ;;
        esac
    fi

    [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]] && return 0

    if [[ "$exit_code" -ne 0 ]]; then
        nds_ui_init
        _app_call_hook "exit_cleanup" "$exit_code" || true
        if [[ "$NDS_UI_COLOR" == true ]]; then
            printf '%s\033[31;1mInstallation failed (exit code %s).\033[0m\n' "$NDS_UI_INDENT_B" "$exit_code" >&2
        else
            printf '%sInstallation failed (exit code %s).\n' "$NDS_UI_INDENT_B" "$exit_code" >&2
        fi
        nds_ui_b ""
        if declare -f nds_install_logs_fetch_hints &>/dev/null; then
            nds_install_logs_fetch_hints
        else
            local log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
            if [[ -f "$log" ]]; then
                nds_ui_i "Full log: ${log}"
                nds_ui_b "Last lines:"
                while IFS= read -r _line; do
                    printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
                done < <(tail -n 12 "$log" 2>/dev/null)
                nds_ui_b ""
            fi
        fi
        if [[ -f "${NDS_INSTALL_DIAG_LOG:-}" ]]; then
            nds_ui_b "Diagnostics (last lines):"
            while IFS= read -r _line; do
                printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
            done < <(tail -n 24 "${NDS_INSTALL_DIAG_LOG}" 2>/dev/null)
            nds_ui_b ""
        fi
        return 0
    fi

    info "Cleaning up session"
    nds_runtime_purge
    _app_call_hook "exit_cleanup" "$exit_code" || true
}
