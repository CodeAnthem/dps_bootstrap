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
    
    nds_field_declare DEPLOY_TOOLS_PATH \
        display="Deploy Tools Installation Path" \
        input=path \
        default="/home/admin/deployTools"

    # Default Values for modules
    # Access - Admin user and SSH
    nds_config_set_default "access" "ADMIN_USER" "admin"
    nds_config_set_default "access" "SUDO_PASSWORD_REQUIRED" "true"
    nds_config_set_default "access" "SSH_ENABLE" "true"
    nds_config_set_default "access" "SSH_PORT" "22"
    nds_config_set_default "access" "SSH_USE_KEY" "true"
    nds_config_set_default "access" "SSH_KEY_TYPE" "ed25519"
    nds_config_set_default "access" "SSH_KEY_PASSPHRASE" "false"

    # Network
    nds_config_set_default "network" "NETWORK_METHOD" "dhcp"

    # Disk & Encryption
    nds_config_set_default "disk" "ENCRYPTION" "true"
    nds_config_set_default "disk" "ENCRYPTION_KEY_METHOD" "urandom"
    nds_config_set_default "disk" "ENCRYPTION_KEY_LENGTH" "64"

    # Boot
    nds_config_set_default "boot" "BOOTLOADER" "systemd-boot"

    # Security
    nds_config_set_default "security" "SECURE_BOOT" "false"
    nds_config_set_default "security" "FIREWALL_ENABLE" "true"
    nds_config_set_default "security" "HARDENING_ENABLE" "true"
    nds_config_set_default "security" "FAIL2BAN_ENABLE" "true"
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
    nixos-generate-config --root /mnt
    step_complete "Hardware config generated"

    # Phase 5: Write NixOS configuration from registered blocks
    step_start "Writing NixOS configuration"
    nds_nixcfg_write "/mnt/etc/nixos/configuration.nix"
    step_complete "Configuration written"

    # Phase 6: Copy nixosConfiguration files if they exist
    local nixos_config_src
    nixos_config_src="$(dirname "$(realpath "$0")")/nixosConfiguration"
    if [[ -d "$nixos_config_src" ]]; then
        step_start "Merging custom NixOS configuration"
        # TODO: Implement merging of custom NixOS config
        # For now, just note it exists
        console "   Custom config found at: $nixos_config_src"
        console "   TODO: Merge with generated config"
        step_complete "Custom config noted"
    fi

    # Phase 7: Install NixOS
    step_start "Installing NixOS system"
    nixos-install --root /mnt --no-root-passwd
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
    section_header "Deploy VM Installation"
    console "This will install a deploy VM to manage NixOS nodes"

    # Configuration workflow
    if ! nds_config_workflow "access" "network" "disk" "boot" "security" "region" "deploy"; then
        error "Configuration cancelled or failed validation"
        return 1
    fi

    # Generate NixOS configuration from modules
    new_section
    section_header "Generating NixOS Configuration"
    
    # Clear any previous config
    nds_nixcfg_clear
    
    # Generate all module configs (they register themselves)
    step_start "Generating module configurations"
    nds_nixcfg_access_auto
    nds_nixcfg_network_auto
    nds_nixcfg_boot_auto
    nds_nixcfg_security_auto
    nds_nixcfg_region_auto
    step_complete "Modules configured"
    
    # System installation
    new_section
    if ! install_system; then
        error "System installation failed"
        return 1
    fi

    # Copy deployTools to user home
    new_section
    if ! install_deploy_tools; then
        warn "Deploy tools installation had issues (non-critical)"
    fi

    # Collect and show secrets
    new_section
    if ! collect_and_show_secrets; then
        warn "Secrets collection had issues (non-critical)"
    fi

    # Show completion summary
    show_completion_summary

    success "Deploy VM installation complete!"
    return 0
}

# =============================================================================
# DEPLOY TOOLS INSTALLATION
# =============================================================================
install_deploy_tools() {
    section_header "Installing Deploy Tools"
    
    local admin_user deploy_tools_src deploy_tools_dest
    admin_user=$(nds_config_get "access" "ADMIN_USER")
    
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"
    deploy_tools_src="${script_dir}/deployTools"
    deploy_tools_dest=$(nds_config_get "deploy" "DEPLOY_TOOLS_PATH")
    
    step_start "Copying deploy tools to $deploy_tools_dest"
    
    if [[ ! -d "$deploy_tools_src" ]]; then
        warn "Deploy tools source not found: $deploy_tools_src"
        return 1
    fi
    
    # Create destination on mounted filesystem
    local mnt_dest="/mnt${deploy_tools_dest}"
    mkdir -p "$mnt_dest"
    
    # Copy tools
    if ! cp -r "$deploy_tools_src"/* "$mnt_dest/"; then
        error "Failed to copy deploy tools"
        return 1
    fi
    
    # Set ownership
    chown -R 1000:1000 "$mnt_dest" 2>/dev/null || true
    
    step_complete "Deploy tools installed"
    success "Deploy tools installed to: $deploy_tools_dest"
    return 0
}

# =============================================================================
# SECRETS COLLECTION AND WARNING
# =============================================================================
collect_and_show_secrets() {
    section_header "Secrets and Keys"
    
    local secrets_dir encryption ssh_key_type admin_user
    secrets_dir="/tmp/dps_secrets_$(date +%s)"
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    ssh_key_type=$(nds_config_get "access" "SSH_KEY_TYPE")
    admin_user=$(nds_config_get "access" "ADMIN_USER")
    
    mkdir -p "$secrets_dir"
    
    console ""
    console "╭───────────────────────────────────────────────────╮"
    console "│  ⚠️  IMPORTANT: Backup These Secrets!            │"
    console "╰───────────────────────────────────────────────────╯"
    console ""
    
    # Collect LUKS key if encryption enabled
    if [[ "$encryption" == "true" ]]; then
        local luks_key="/tmp/luks_key.txt"
        if [[ -f "$luks_key" ]]; then
            cp "$luks_key" "$secrets_dir/"
            console "🔐 LUKS Encryption Key:"
            console "   Location: $secrets_dir/luks_key.txt"
            console "   ⚠️  Required to unlock encrypted disk!"
            console ""
        fi
    fi
    
    # Show SSH key locations
    console "🔑 SSH Keys ($ssh_key_type):"
    console "   Private: /home/${admin_user}/.ssh/id_${ssh_key_type}"
    console "   Public:  /home/${admin_user}/.ssh/id_${ssh_key_type}.pub"
    console "   ⚠️  Required for remote node deployment!"
    console ""
    
    # Show Age key location
    console "🔐 Age Encryption Key (for SOPS):"
    console "   Location: /home/${admin_user}/.config/sops/age/keys.txt"
    console "   ⚠️  Required for secrets management!"
    console ""
    
    # Show private repo SSH key if configured
    local deploy_ssh_key
    deploy_ssh_key=$(nds_config_get "deploy" "DEPLOY_SSH_KEY_PATH")
    if [[ -n "$deploy_ssh_key" ]]; then
        console "🔑 Private Repository SSH Key:"
        console "   Path: $deploy_ssh_key"
        console "   ⚠️  Required for private git repository access!"
        console ""
    fi
    
    warn "Secrets directory: $secrets_dir"
    warn "This directory is in /tmp and will be DELETED on reboot!"
    warn "Back up all secrets BEFORE rebooting!"
    console ""
    
    return 0
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# Helper functions for Deploy VM specific operations can be added here
