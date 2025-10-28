#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - Deploy VM Action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-17 | Modified: 2025-10-26
# Description:   Deploy VM management hub setup with deployment tools and infrastructure management
# Feature:       LUKS encryption, SOPS integration, SSH orchestration, mass deployment capabilities
# Author:        DPS Project
# ==================================================================================================

set -euo pipefail

# =============================================================================
# ACTION METADATA
# =============================================================================
# readonly ACTION_VERSION="1.0.0"

# =============================================================================
# ACTION CONFIGURATION
# =============================================================================
deploy_init_callback() {
    echo deploy_init_callback
    # Declare action-specific fields
    nds_field_declare GIT_REPO_URL \
        display="Private Git Repository" \
        input=url \
        default="https://github.com/user/repo.git" \
        required=true
    
    nds_field_declare DEPLOY_SSH_KEY_PATH \
        display="Deploy SSH Key Path" \
        input=path \
        default="/root/.ssh/deploy_key" \
        required=true

    # NOTE: No need to call nds_config_use_module - workflow auto-initializes all modules!
    # The workflow will automatically initialize: system, network, disk, boot, ssh, security, region
    
    # Apply Deploy VM action-specific defaults
    # System
    nds_config_set_default "system" "ADMIN_SHELL" "bash"
    nds_config_set_default "system" "AUTO_UPGRADE" "true"
    nds_config_set_default "system" "DEFAULT_EDITOR" "vim"
    
    # Network
    nds_config_set_default "network" "NETWORK_METHOD" "dhcp"
    
    # Disk & Encryption
    nds_config_set_default "disk" "ENCRYPTION" "true"
    nds_config_set_default "disk" "ENCRYPTION_KEY_METHOD" "urandom"
    nds_config_set_default "disk" "ENCRYPTION_KEY_LENGTH" "64"
    
    # Boot & Secure Boot
    nds_config_set_default "boot" "BOOTLOADER" "systemd-boot"
    nds_config_set_default "boot" "SECURE_BOOT_METHOD" "lanzaboote"
    
    # SSH Hardening
    nds_config_set_default "ssh" "SSH_ENABLE" "true"
    nds_config_set_default "ssh" "SSH_KEY_TYPE" "ed25519"
    nds_config_set_default "ssh" "SSH_PASSWORD_AUTH" "false"
    nds_config_set_default "ssh" "SSH_ROOT_LOGIN" "prohibit-password"
    
    # Security
    nds_config_set_default "security" "FIREWALL_ENABLE" "true"
    nds_config_set_default "security" "FAIL2BAN_ENABLE" "true"

    echo deploy_init_callback_done
}

# deploy_get_active_fields() {
#     echo "GIT_REPO_URL"
#     echo "DEPLOY_SSH_KEY_PATH"
# }

# deploy_validate_extra() {
#     return 0
# }



# =============================================================================
# INSTALLATION WORKFLOW
# =============================================================================

# Install system - disk partitioning, encryption, NixOS installation
install_system() {
    section_header "System Installation"
    
    local disk encryption hostname
    disk=$(nds_config_get "disk" "DISK_TARGET")
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    hostname=$(nds_config_get "network" "HOSTNAME")
    
    # Phase 1: Disk partitioning
    step_start "Partitioning disk: $disk"
    if ! partition_disk "$encryption" "$disk"; then
        error "Disk partitioning failed"
        return 1
    fi
    step_complete "Disk partitioned"
    
    # Phase 2: Encryption setup (if enabled)
    if [[ "$encryption" == "true" ]]; then
        step_start "Setting up LUKS encryption"
        if ! setup_encryption; then
            error "Encryption setup failed"
            return 1
        fi
        step_complete "Encryption configured"
    fi
    
    # Phase 3: Mount filesystems
    step_start "Mounting filesystems"
    if ! mount_filesystems "$encryption"; then
        error "Failed to mount filesystems"
        return 1
    fi
    step_complete "Filesystems mounted"
    
    # Phase 4: Generate hardware config
    step_start "Generating hardware configuration"
    if ! generate_hardware_config "$hostname"; then
        error "Hardware configuration generation failed"
        return 1
    fi
    step_complete "Hardware config generated"
    
    # Phase 5: Create NixOS configuration
    step_start "Creating NixOS configuration"
    if ! create_deploy_vm_config "$hostname" "$encryption"; then
        error "NixOS configuration creation failed"
        return 1
    fi
    step_complete "NixOS configuration created"
    
    # Phase 6: Install NixOS
    step_start "Installing NixOS"
    if ! install_deploy_vm "$hostname"; then
        error "NixOS installation failed"
        return 1
    fi
    step_complete "NixOS installed"
    
    success "System installation complete"
    return 0
}

# =============================================================================
# POST-INSTALL SETUP
# =============================================================================

# Post-install configuration - keys, repository, tools
post_install_setup() {
    section_header "Post-Install Configuration"
    
    local git_repo admin_user
    git_repo=$(nds_config_get "deploy" "GIT_REPO_URL")
    admin_user=$(nds_config_get "system" "ADMIN_USER")
    
    # Generate SSH keys for admin user
    step_start "Generating SSH keys for $admin_user"
    local ssh_key_path="/mnt/home/${admin_user}/.ssh/id_ed25519"
    mkdir -p "$(dirname "$ssh_key_path")"
    if ! generate_ssh_key "$ssh_key_path" "" "$(nds_config_get "network" "HOSTNAME")"; then
        warn "SSH key generation failed (non-critical)"
    else
        step_complete "SSH keys generated"
    fi
    
    # Generate Age encryption key for SOPS
    step_start "Generating Age encryption key"
    local age_key_path="/mnt/home/${admin_user}/.config/sops/age/keys.txt"
    mkdir -p "$(dirname "$age_key_path")"
    if ! generate_age_key "$age_key_path"; then
        warn "Age key generation failed (non-critical)"
    else
        step_complete "Age keys generated"
    fi
    
    # Set proper ownership for user files
    step_start "Setting file permissions"
    if [[ -d "/mnt/home/${admin_user}" ]]; then
        chown -R 1000:1000 "/mnt/home/${admin_user}" 2>/dev/null || true
    fi
    step_complete "Permissions set"
    
    success "Post-install configuration complete"
    return 0
}

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================

# Show installation completion summary with next steps
show_completion_summary() {
    new_section
    section_header "Installation Complete!"
    
    local hostname encryption disk admin_user git_repo
    hostname=$(nds_config_get "network" "HOSTNAME")
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    disk=$(nds_config_get "disk" "DISK_TARGET")
    admin_user=$(nds_config_get "system" "ADMIN_USER")
    git_repo=$(nds_config_get "deploy" "GIT_REPO_URL")
    
    console ""
    console "╭─────────────────────────────────────────────╮"
    console "│  Deploy VM Ready: $hostname"
    console "╰─────────────────────────────────────────────╯"
    console ""
    
    # Show encryption key backup warning
    if [[ "$encryption" == "true" ]]; then
        warn "ENCRYPTION KEY BACKUP REQUIRED!"
        console "   Encryption is enabled on $disk"
        console "   ⚠️  Backup LUKS key before rebooting!"
        console "   Key location: /tmp/luks_key.txt (if saved)"
        console ""
    fi
    
    console "📋 Next Steps:"
    console "   1️⃣  Reboot the system"
    console "   2️⃣  Login as: $admin_user"
    console "   3️⃣  Clone private repository: $git_repo"
    console "   4️⃣  Configure SOPS with Age keys"
    console "   5️⃣  Setup SSH keys for node deployment"
    console "   6️⃣  Begin deploying managed nodes"
    console ""
    
    console "📚 Documentation:"
    console "   - README: /etc/nixos/README.md"
    console "   - SSH Key: /home/${admin_user}/.ssh/id_ed25519.pub"
    console "   - Age Key: /home/${admin_user}/.config/sops/age/keys.txt"
    console ""
}

# =============================================================================
# MAIN SETUP FUNCTION
# =============================================================================
setup() {    
    echo setup
    # Phase 1: Configuration workflow (auto-initializes modules)
    # Run configuration workflow (error fix → interactive → validate)
    if ! nds_config_workflow "system" "network" "disk" "boot" "ssh" "security" "region" "deploy"; then
        error "Configuration cancelled or failed validation"
        return 1
    fi
    
    # # Phase 2: Show final configuration summary
    # new_section
    # section_header "Configuration Summary"
    # nds_module_display "network"
    # console ""
    # nds_module_display "disk"
    # console ""
    # nds_module_display "system"
    # console ""
    # nds_module_display "deploy"
    
    # # Phase 3: Confirm installation
    # console ""
    # read -p "Proceed with installation? [y/N]: " -n 1 -r confirm
    # echo
    # if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    #     warn "Installation cancelled by user"
    #     return 1
    # fi
    
    echo "setup done"
    exit 0
    # Phase 4: System installation
    new_section
    if ! install_system; then
        error "System installation failed"
        return 1
    fi
    
    # Phase 5: Post-install setup
    new_section
    if ! post_install_setup; then
        warn "Post-install setup had issues (non-critical)"
    fi
    
    # Phase 6: Show completion summary
    show_completion_summary
    
    success "Deploy VM installation complete!"
    return 0
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# Helper functions for Deploy VM specific operations can be added here
