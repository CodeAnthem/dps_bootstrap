#!/usr/bin/env bash
# ==================================================================================================
# NDS - App CLI helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Parse app CLI flags and render help text
# ==================================================================================================

# Description: Print app CLI usage and registered skip variables.
# Arguments:
# - app_path: <String> Absolute path to `src/app`
nds_app_show_help() {
    local app_path="${1:?app path}"
    local script_dir="${app_path%/app}"
    local skip_var

    nds_import_file "${script_dir}/app/lifecycle/lifecycle_logic.sh" || return 1
    nds_lifecycle_load_core "$script_dir" || return 1
    nds_lifecycle_load_ui "$script_dir" || return 1
    nds_lifecycle_load_actions "$script_dir" || return 1

    printf 'Usage: src/app/main.sh [options]\n\n'
    printf 'Options:\n'
    printf '  --auto-confirm   Skip interactive menus and Y/n prompts (headless install)\n'
    printf '  --skip-menu      Skip the configuration category menu when validation passes\n'
    printf '  --action NAME    Enter action NAME directly (e.g. installFlake)\n'
    printf '  --help           Show this help\n\n'
    printf 'Environment:\n'
    printf '  NDS_ACTION        Action name — skip action picker\n'
    printf '  NDS_AUTO_CONFIRM  Umbrella — same as --auto-confirm\n'
    printf '  Registered skip vars:\n'
    for skip_var in "${_NDS_SKIP_REGISTRY[@]}"; do
        printf '    %s\n' "$skip_var"
    done
}

# Description: Parse CLI flags and export app env settings.
nds_app_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto-confirm) export _NDS_AUTO_CONFIRM_REQUESTED=true; shift ;;
            --skip-menu) export NDS_SKIP_MENU=true; shift ;;
            --action)
                [[ -n "${2:-}" ]] || { echo "Missing value for --action"; return 1; }
                export NDS_ACTION="$2"
                shift 2
                ;;
            --help|-h)
                nds_app_show_help "$APP_DIR" || return 1
                return 2
                ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done
    return 0
}
