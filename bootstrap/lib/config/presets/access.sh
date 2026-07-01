#!/usr/bin/env bash
# ==================================================================================================
# NDS - Access preset (admin user, SSH)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-01
# Description:   Admin user credentials and SSH access for the installed system
# ==================================================================================================

access_init() {
    nds_configurator_preset_set_display "access" "Access"
    nds_configurator_preset_set_priority "access" 15

    nds_configurator_var_declare ADMIN_USER \
        display="Admin username" \
        input=username \
        default="admin" \
        required=true

    nds_configurator_var_declare ADMIN_PASSWORD_AUTO \
        display="Auto-generate admin password" \
        input=toggle \
        default=true \
        help="Generate a random admin password from /dev/urandom and save it in the install backup. Disable to type your own."

    nds_configurator_var_declare ADMIN_PASSWORD_LENGTH \
        display="Admin password length (bytes)" \
        input=int \
        default=32 \
        min=16 \
        max=128 \
        help="Random bytes from /dev/urandom (hex-encoded). 32 bytes = 64 hex chars."

    nds_configurator_var_declare ADMIN_PASSWORD \
        display="Admin password" \
        input=secret \
        default="" \
        required=false \
        minlen=12 \
        help="Type the admin user's password (hidden). Used when auto-generate is off."

    nds_configurator_var_declare ADMIN_SSH_KEY \
        display="Admin SSH public key (optional)" \
        input=string \
        default="" \
        required=false \
        help="Your SSH public key for the admin user, e.g. ssh-ed25519 AAAA... user@host. Leave empty to rely on the password."

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

    nds_configurator_var_declare SSH_PASSWORD_AUTH \
        display="Allow SSH password login" \
        input=toggle \
        default=true \
        help="Let the admin user log in over SSH with the password. Disable after you set up key auth."
}

access_get_active() {
    local auto
    auto=$(nds_configurator_config_get "ADMIN_PASSWORD_AUTO")

    echo "ADMIN_USER"
    echo "ADMIN_PASSWORD_AUTO"
    if [[ "$auto" == "true" ]]; then
        echo "ADMIN_PASSWORD_LENGTH"
    else
        echo "ADMIN_PASSWORD"
    fi
    echo "ADMIN_SSH_KEY"
    echo "SUDO_PASSWORD_REQUIRED"
    echo "SSH_ENABLE"
    if [[ "$(nds_configurator_config_get "SSH_ENABLE")" == "true" ]]; then
        echo "SSH_PORT"
        echo "SSH_PASSWORD_AUTH"
    fi
}

access_validate_extra() {
    local ssh_enable ssh_pw_auth admin_ssh_key auto admin_pw

    ssh_enable=$(nds_configurator_config_get "SSH_ENABLE")
    ssh_pw_auth=$(nds_configurator_config_get "SSH_PASSWORD_AUTH")
    admin_ssh_key=$(nds_configurator_config_get "ADMIN_SSH_KEY")
    auto=$(nds_configurator_config_get "ADMIN_PASSWORD_AUTO")
    admin_pw=$(nds_configurator_config_get "ADMIN_PASSWORD")

    if [[ "$auto" != "true" && -z "$admin_pw" ]]; then
        validation_error "Auto-generate is off — an admin password is required"
        return 1
    fi

    # No way to log in over SSH: key auth only (password disabled) but no key set.
    if [[ "$ssh_enable" == "true" && "$ssh_pw_auth" != "true" && -z "$admin_ssh_key" ]]; then
        validation_error "SSH password login is off and no admin SSH key is set — you would be locked out"
        return 1
    fi

    return 0
}
