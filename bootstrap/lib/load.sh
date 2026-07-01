#!/usr/bin/env bash
# ==================================================================================================
# NDS - Library loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-06-30
# Description:   Load feature packages (config, install, nixcfg)
# ==================================================================================================

# =============================================================================
# CONFIGURATOR
# =============================================================================

nds_configurator_init() {
    debug "Initializing configurator..."

    # platform.sh lives in lib/core and is auto-loaded by nds_bootstrap_load_libs.

    nds_import_dir "${SCRIPT_DIR}/lib/config" false || {
        fatal "Failed to load configurator logic"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/config/inputs" true || {
        fatal "Failed to load input validators"
        return 1
    }

    for preset_file in "${SCRIPT_DIR}/lib/config/presets/"*.sh; do
        [[ -f "$preset_file" ]] || continue

        local preset_name
        preset_name=$(basename "$preset_file" .sh)

        nds_import_file "$preset_file" || {
            error "Failed to load preset: $preset_name"
            return 1
        }

        _nds_configurator_preset_register "$preset_name"
        _nds_configurator_cache_preset_functions "$preset_name"

        if _nds_configurator_preset_is_enabled "$preset_name"; then
            _nds_configurator_preset_init "$preset_name" || {
                error "Failed to init preset: $preset_name"
                return 1
            }
        fi
    done

    _nds_configurator_apply_env

    debug "Configurator initialized (${#PRESET_REGISTRY[@]} presets)"
    return 0
}

_nds_configurator_preset_register() {
    local preset="$1"
    PRESET_REGISTRY["$preset"]="enabled"
    PRESET_META["${preset}__priority"]="50"
}

_nds_configurator_cache_preset_functions() {
    local preset="$1"

    if type "${preset}_get_active" &>/dev/null; then
        PRESET_FUNCTIONS["${preset}__get_active"]="true"
    fi

    if type "${preset}_validate_extra" &>/dev/null; then
        PRESET_FUNCTIONS["${preset}__validate_extra"]="true"
    fi
}

_nds_configurator_preset_init() {
    local preset="$1"
    PRESET_CONTEXT="$preset"

    local init_func="${preset}_init"
    if type "$init_func" &>/dev/null; then
        $init_func || {
            PRESET_CONTEXT=""
            return 1
        }
    fi

    PRESET_CONTEXT=""
    return 0
}

_nds_configurator_apply_env() {
    for key in "${!VAR_META[@]}"; do
        if [[ "$key" =~ ^(.+)__display$ ]]; then
            local varname="${BASH_REMATCH[1]}"
            local env_var="NDS_${varname}"
            if [[ -n "${!env_var:-}" ]]; then
                CONFIG_DATA["$varname"]="${!env_var}"
                debug "Env override: $env_var=${!env_var}"
            fi
        fi
    done
}

# =============================================================================
# INSTALLATION STACK
# =============================================================================

nds_installation_init() {
    debug "Loading installation stack..."

    # install/ holds the installer + merged partition modules (disk, disko,
    # detect, compat, partitionTools, encryption, boot, bundle, etc.).
    nds_import_dir "${SCRIPT_DIR}/lib/install" false || {
        fatal "Failed to load install modules"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/lib/nixcfg/builder.sh" || {
        fatal "Failed to load nixcfg builder"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/nixcfg/blocks" false || {
        fatal "Failed to load nixcfg blocks"
        return 1
    }

    debug "Installation stack loaded"
    return 0
}
