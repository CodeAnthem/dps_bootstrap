#!/usr/bin/env bash
# ==================================================================================================
# NDS - Framework bootstrap loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-08-03
# ==================================================================================================

declare -ga NDS_DEFAULT_PRESET_BUNDLE=(
    disk encryption region network boot access quick platform security
)

declare -g NDS_FRAMEWORK_REST_LOADED=false
declare -g NDS_FRAMEWORK_SETTINGS_LOADED=false

# Description: Load settingsManager and validator-facing framework pieces on demand.
nds_framework_load_settings_manager() {
    [[ "${NDS_FRAMEWORK_SETTINGS_LOADED}" == "true" ]] && return 0

    nds_import_file "${SCRIPT_DIR}/framework/settings-manager/load.sh" || return 1
    nds_settings_manager_load \
        "${SCRIPT_DIR}/framework/settings-manager" \
        "${SCRIPT_DIR}/standalone/validators" || return 1

    NDS_FRAMEWORK_SETTINGS_LOADED=true
    return 0
}

# Description: Catalog builtin presets without enabling or seeding.
nds_settings_catalog_init() {
    debug "Cataloging builtin presets..."
    nds_preset_catalog_builtin "$SCRIPT_DIR" || {
        fatal "Failed to catalog builtin presets"
        return 1
    }
    debug "Preset catalog ready (${#PRESET_REGISTRY[@]} cataloged)"
    return 0
}

# Description: Catalog + enable default classic bundle + seed (tests / non-action use).
nds_cfg_init() {
    debug "Initializing settings manager..."

    nds_framework_load_settings_manager || return 1
    nds_settings_catalog_init || return 1

    nds_preset_enable_bundle "$SCRIPT_DIR" "${NDS_DEFAULT_PRESET_BUNDLE[@]}" || {
        fatal "Failed to enable default preset bundle"
        return 1
    }

    nds_cfg_seed_defaults

    debug "Settings initialized (${#PRESET_REGISTRY[@]} cataloged, hooks loaded on demand)"
    return 0
}

nds_framework_load_remaining() {
    [[ "${NDS_FRAMEWORK_REST_LOADED}" == "true" ]] && return 0

    debug "Loading remaining framework modules..."

    nds_import_file "${SCRIPT_DIR}/framework/git/load.sh" || return 1
    nds_git_tools_load "${SCRIPT_DIR}/framework/git" || {
        fatal "Failed to load git tools"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/features/install/load.sh" || return 1
    nds_install_load "${SCRIPT_DIR}/features/install" || {
        fatal "Failed to load install modules"
        return 1
    }

    if declare -f nds_install_logs_init &>/dev/null; then
        nds_install_logs_init || true
    fi

    nds_import_file "${SCRIPT_DIR}/features/flake/load.sh" || return 1
    nds_flake_tools_load "${SCRIPT_DIR}/features/flake" || {
        fatal "Failed to load flake tools"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/features/nixcfg/load.sh" || return 1
    nds_nixwriter_load "${SCRIPT_DIR}/features/nixcfg" || {
        fatal "Failed to load nixWriter"
        return 1
    }

    NDS_FRAMEWORK_REST_LOADED=true
    debug "Remaining framework modules loaded"
    return 0
}

# Description: Load git tools and cache gh early (before action menu).
# Lets exit cleanup detect/clear leftover gh sessions even if the user aborts
# at the action picker. Safe to call repeatedly.
nds_framework_warmup_git_gh() {
    if [[ "${NDS_GIT_TOOLS_LOADED:-false}" != "true" ]]; then
        nds_import_file "${SCRIPT_DIR}/framework/git/load.sh" || return 0
        nds_git_tools_load "${SCRIPT_DIR}/framework/git" || return 0
    fi
    if declare -f nds_git_gh_ensure_prefetch &>/dev/null; then
        nds_git_gh_ensure_prefetch || true
    fi
    # Remember leftover login so abort-from-menu still offers to clear it.
    if declare -f nds_git_gh_host_logged_in &>/dev/null && nds_git_gh_host_logged_in; then
        NDS_GIT_GH_LEFTOVER=true
        export NDS_GIT_GH_LEFTOVER
        info "Leftover GitHub CLI login detected on this ISO (offered on exit)"
        nds_install_log "git: leftover gh session detected at warmup"
    else
        unset NDS_GIT_GH_LEFTOVER 2>/dev/null || true
        nds_install_log "git: no leftover gh session at warmup"
    fi
    return 0
}

# Description: After action import: allow settingsManager extension, catalog presets,
#              then load heavy modules. Action enables its preset bundle next.
nds_framework_prepare_action_runtime() {
    nds_framework_load_settings_manager || return 1

    if declare -f action_extend_settings_manager &>/dev/null; then
        action_extend_settings_manager || return 1
    fi

    nds_settings_catalog_init || return 1
    nds_framework_load_remaining || return 1
    return 0
}
