#!/usr/bin/env bash
# ==================================================================================================
# NDS - Library loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-06-29
# Description:   Load feature packages (configurator, installer, classicConfig, partition, setup)
# ==================================================================================================

# =============================================================================
# CONFIGURATOR
# =============================================================================

nds_configurator_init() {
    info "Initializing configurator..."

    nds_import_dir "${SCRIPT_DIR}/lib/configurator" false || {
        fatal "Failed to load configurator logic"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/configurator/inputs" true || {
        fatal "Failed to load input validators"
        return 1
    }

    for preset_file in "${SCRIPT_DIR}/lib/configurator/presets/"*.sh; do
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

    success "Configurator initialized (${#PRESET_REGISTRY[@]} presets)"
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
    info "Loading installation stack..."

    nds_import_dir "${SCRIPT_DIR}/lib/installer" false || {
        fatal "Failed to load installer"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/lib/classicConfig/builder.sh" || {
        fatal "Failed to load classicConfig builder"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/classicConfig/blocks" false || {
        fatal "Failed to load classicConfig blocks"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/setup" false || {
        fatal "Failed to load setup helpers"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/lib/partition/partitionTools.sh" || {
        fatal "Failed to load partition tools"
        return 1
    }

    nds_partition_load || {
        fatal "Failed to load partition tool modules"
        return 1
    }

    success "Installation stack loaded"
    return 0
}
