#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-16
# Description:   Automated NixOS deployment system with Deploy VM and managed node architecture
# Feature:       Interactive mode selection, helper libraries, embedded workflows
# ==================================================================================================

set -euo pipefail

# ----------------------------------------------------------------------------------
# SCRIPT METADATA
# ----------------------------------------------------------------------------------
readonly SCRIPT_VERSION="3.0.6"
readonly SCRIPT_NAME="NixOS Bootstrapper | DPS Project"

# ----------------------------------------------------------------------------------
# IMPORT LIBRARIES
# ----------------------------------------------------------------------------------

# Get script directory for sourcing libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper libraries
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"
# shellcheck source=lib/disk-setup.sh
source "$SCRIPT_DIR/lib/disk-setup.sh"
# shellcheck source=lib/network-setup.sh
source "$SCRIPT_DIR/lib/network-setup.sh"
# shellcheck source=lib/nix-setup.sh
source "$SCRIPT_DIR/lib/nix-setup.sh"

# Setup cleanup trap
trap cleanup EXIT


# ----------------------------------------------------------------------------------
# CONFIGURATION SETUP
# ----------------------------------------------------------------------------------
setup_deploy_defaults() {
    # Deploy VM defaults
    export NDS_HOSTNAME="${NDS_HOSTNAME:-deploy-01}"
    export NDS_NETWORK_METHOD="${NDS_NETWORK_METHOD:-dhcp}"
    export NDS_NETWORK_GATEWAY="${NDS_NETWORK_GATEWAY:-192.168.1.1}"
    export NDS_ENCRYPTION="${NDS_ENCRYPTION:-y}"
    export NDS_DISK_TARGET="${NDS_DISK_TARGET:-/dev/sda}"
    export NDS_ADMIN_USER="${NDS_ADMIN_USER:-admin}"
}

setup_node_defaults() {
    # Managed node defaults
    export NDS_HOSTNAME="${NDS_HOSTNAME:-}"
    export NDS_ROLE="${NDS_ROLE:-}"
    export NDS_IP_ADDRESS="${NDS_IP_ADDRESS:-}"
    export NDS_NETWORK_GATEWAY="${NDS_NETWORK_GATEWAY:-192.168.1.1}"
    export NDS_NETWORK_DNS_PRIMARY="${NDS_NETWORK_DNS_PRIMARY:-1.1.1.1}"
    export NDS_NETWORK_DNS_SECONDARY="${NDS_NETWORK_DNS_SECONDARY:-1.0.0.1}"
    export NDS_ENCRYPTION="${NDS_ENCRYPTION:-n}"
    export NDS_DISK_TARGET="${NDS_DISK_TARGET:-/dev/sda}"
    export NDS_ADMIN_USER="${NDS_ADMIN_USER:-admin}"
}


# ----------------------------------------------------------------------------------
# DEPLOY VM WORKFLOW
# ----------------------------------------------------------------------------------
deploy_vm_workflow() {
    section_header "Deploy VM Installation Workflow"
    
    # Setup defaults and validate
    step_start "Setting up configuration"
    setup_deploy_defaults
    validate_deploy_config
    step_complete "Configuration setup"
    
    # Show configuration and get confirmation
    show_configuration_preview "deploy"
    
    # Get GitHub token for private repo access
    local github_token
    github_token=$(prompt_github_token)
    
    new_section
    section_header "System Installation"
    
    # Setup encryption if enabled
    step_start "Setting up disk encryption"
    setup_encryption "$NDS_ENCRYPTION"
    step_complete "Disk encryption setup"
    
    # Partition and mount disk
    step_start "Partitioning and mounting disk"
    partition_disk "$NDS_ENCRYPTION"
    mount_filesystems "$NDS_ENCRYPTION"
    step_complete "Disk partitioning and mounting"
    
    # Generate hardware config
    step_start "Generating hardware configuration"
    generate_hardware_config "$NDS_HOSTNAME"
    step_complete "Hardware configuration generation"
    
    # Create Deploy VM configuration
    step_start "Creating Deploy VM configuration"
    create_deploy_vm_config "$NDS_HOSTNAME" "$NDS_ENCRYPTION"
    step_complete "Deploy VM configuration creation"
    
    # Install NixOS (no flake needed for Deploy VM)
    step_start "Installing NixOS system"
    install_deploy_vm "$NDS_HOSTNAME"
    step_complete "NixOS system installation"
    
    new_section
    section_header "Installation Complete!"
    pass "Deploy VM installation completed successfully!"
    echo
    printf "📋 Next steps:\n"
    printf "   1️⃣  Reboot the system\n"
    printf "   2️⃣  Clone your private repository with write access\n"
    printf "   3️⃣  Set up SOPS keys and SSH keys for cluster management\n"
    printf "   4️⃣  Use deployment tools to create managed nodes\n"
    echo
}


# ----------------------------------------------------------------------------------
# MANAGED NODE WORKFLOW
# ----------------------------------------------------------------------------------
managed_node_workflow() {
    log "Starting Managed Node workflow"
    
    # Setup defaults and validate
    setup_node_defaults
    
    # Prompt for required values if not set
    [[ -z "$NDS_ROLE" ]] && read -p "Enter node role (worker/gateway/gpu-worker): " NDS_ROLE
    [[ -z "$NDS_HOSTNAME" ]] && read -p "Enter hostname: " NDS_HOSTNAME
    [[ -z "$NDS_IP_ADDRESS" ]] && read -p "Enter IP address: " NDS_IP_ADDRESS
    
    # Export the values
    export NDS_ROLE NDS_HOSTNAME NDS_IP_ADDRESS
    
    validate_node_config
    
    # Show configuration and get confirmation
    show_configuration_preview "node"
    
    # Get GitHub token and private repo URL
    local github_token
    github_token=$(prompt_github_token)
    
    local private_repo
    read -p "Enter your private NixOS flake repository URL: " private_repo
    
    # Setup encryption if enabled
    setup_encryption "$NDS_ENCRYPTION"
    
    # Partition and mount disk
    partition_disk "$NDS_ENCRYPTION"
    mount_filesystems "$NDS_ENCRYPTION"
    
    # Clone private repository
    local private_repo_path="/mnt/etc/nixos-flake"
    clone_repository "$private_repo" "$private_repo_path" "$github_token"
    
    # Generate hardware config
    generate_hardware_config "$NDS_HOSTNAME"
    
    # Create node configuration
    create_node_config "$NDS_ROLE" "$NDS_HOSTNAME" "$NDS_ENCRYPTION" "$private_repo_path"
    
    # Install NixOS with flake and hardware override
    install_managed_node "$NDS_HOSTNAME" "$private_repo_path"
    
    pass "Managed node installation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Reboot the system"
    echo "2. Node will automatically pull configurations from private repository"
    echo "3. Use 'dps-update' command to update system configuration"
    echo "4. Verify connectivity with Deploy VM"
}

# ----------------------------------------------------------------------------------
# MAIN FUNCTION
# ----------------------------------------------------------------------------------
main() {
    echo
    echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Setup runtime environment
    setup_runtime
    
    # Select deployment mode
    local mode; mode=$(select_mode)
    case "$mode" in
        "deploy")
            deploy_vm_workflow
            ;;
        "node")
            managed_node_workflow
            ;;
        *)
            error "Invalid mode: $mode"
            ;;
    esac
    
    # Show encryption key backup reminder if encryption was used
    if [[ "${NDS_ENCRYPTION:-}" == "y" && -n "${NDS_KEY_FILE:-}" ]]; then
        echo
        echo "IMPORTANT: Encryption key saved to: ${NDS_KEY_FILE}"
        echo "Make sure to backup this key before rebooting!"
    fi
}

# ----------------------------------------------------------------------------------
# SCRIPT EXECUTION
# ----------------------------------------------------------------------------------
main "$@"
