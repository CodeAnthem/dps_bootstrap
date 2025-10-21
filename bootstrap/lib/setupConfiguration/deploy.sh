#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-10-22
# Description:   Deploy-specific configuration module
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================
deploy_init_callback() {
    # MODULE_CONTEXT is already set to "deploy"
    
    field_declare GIT_REPO_URL \
        display="Private Git Repository" \
        default="https://github.com/user/repo.git" \
        validator=validate_url \
        error="Invalid Git URL format"
    
    field_declare DEPLOY_SSH_KEY_PATH \
        display="Deploy SSH Key Path" \
        default="/root/.ssh/deploy_key" \
        validator=validate_path
}

# =============================================================================
# ACTIVE FIELDS LOGIC
# =============================================================================
deploy_get_active_fields() {
    # All deploy fields are always active
    echo "GIT_REPO_URL"
    echo "DEPLOY_SSH_KEY_PATH"
}

# =============================================================================
# CROSS-FIELD VALIDATION
# =============================================================================
deploy_validate_extra() {
    # No cross-field validation needed
    return 0
}
