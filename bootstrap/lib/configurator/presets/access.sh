#!/usr/bin/env bash
# ==================================================================================================
# NDS - Access preset (admin user, SSH)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# ==================================================================================================

access_init() {
    nds_configurator_preset_set_display "access" "Access"
    nds_configurator_preset_set_priority "access" 15

    nds_configurator_var_declare ADMIN_USER \
        display="Admin username" \
        input=username \
        default="admin" \
        required=true

    nds_configurator_var_declare SUDO_PASSWORD_REQUIRED \
        display="Sudo requires password" \
        input=toggle \
        default=true

    nds_configurator_var_declare SSH_ENABLE \
        display="Enable SSH" \
        input=toggle \
        default=true

    nds_configurator_var_declare SSH_PORT \
        display="SSH port" \
        input=port \
        default="22"

    nds_configurator_var_declare SSH_USE_KEY \
        display="SSH key auth (disable password login)" \
        input=toggle \
        default=true
}

access_get_active() {
    echo "ADMIN_USER"
    echo "SUDO_PASSWORD_REQUIRED"
    echo "SSH_ENABLE"
    echo "SSH_PORT"
    echo "SSH_USE_KEY"
}

access_validate_extra() {
    return 0
}
