#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-10-29
# Description:   Configuration system master file - entry point for config feature
# Feature:       Category-based configuration with field validation and interactive prompts
# ==================================================================================================

# =============================================================================
# INITIALIZE CONFIGURATION FEATURE
# =============================================================================
# Initialize configuration system - called by main.sh
# This loads all config components and prepares the system
nds_config_init() {
    # Load core config logic files (data, field, category, api)
    info "Loading configuration system..."
    nds_source_dir "${SCRIPT_DIR}/lib/config" false || {
        fatal "Failed to load configuration logic"
        return 1
    }

    # Load input validators (recursive - loads all subfolders)
    nds_source_dir "${SCRIPT_DIR}/lib/config/inputs" true || {
        fatal "Failed to load input validators"
        return 1
    }

    # Load all categories (auto-discovery)
    nds_source_dir "${SCRIPT_DIR}/lib/config/categories" false || {
        fatal "Failed to load categories"
        return 1
    }

    success "Configuration feature initialized"
    return 0
}

# =============================================================================
# ACTIVATE CONFIGURATION CATEGORIES
# =============================================================================
# Activate all categories - called by main.sh before sourcing action setup.sh
# Must be called AFTER nds_config_init()
nds_config_activate_categories() {
    # Auto-discover categories from loaded files (find all *_init_callback functions)
    local category_callbacks
    category_callbacks=$(declare -F | grep -oP '(?<=declare -f )\w+(?=_init_callback)')

    if [[ -z "$category_callbacks" ]]; then
        warn "No categories found"
        return 0
    fi

    # Initialize each discovered category
    while IFS= read -r category; do
        _nds_config_init_category "$category" || {
            error "Failed to initialize category: $category"
            return 1
        }
    done <<< "$category_callbacks"

    info "Configuration system initialized ($(echo "$category_callbacks" | wc -l) categories)"
    return 0
}

# =============================================================================
# INTERNAL: INITIALIZE SINGLE CATEGORY
# =============================================================================

# Initialize a single category by calling its init callback
_nds_config_init_category() {
    local category="$1"

    # Set context
    MODULE_CONTEXT="$category"

    # Call init callback (category file already loaded above)
    local init_callback="${category}_init_callback"
    if type "$init_callback" &>/dev/null; then
        $init_callback || {
            error "Failed to run init callback for category: $category"
            return 1
        }
    else
        error "Init callback not found: $init_callback"
        return 1
    fi

    # Clear context
    MODULE_CONTEXT=""

    return 0
}
