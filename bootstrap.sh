#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2024-10-15 | Modified: 2025-10-15
# Description:   Automated NixOS deployment system with Deploy VM and managed node architecture
# Feature:       Interactive mode selection, helper libraries, embedded workflows
# ==================================================================================================

set -euo pipefail

# =============================================================================
# SCRIPT METADATA
# =============================================================================
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="DPS Bootstrap"

# =============================================================================
# BOOTSTRAP REPOSITORY SETUP
# =============================================================================

# If running from one-liner, clone bootstrap repo to /tmp
if [[ "${BASH_SOURCE[0]}" == "/dev/stdin" ]] || [[ "${BASH_SOURCE[0]}" =~ ^/dev/fd/ ]]; then
    BOOTSTRAP_DIR="/tmp/dps_bootstrap_$$"
    echo "One-liner detected, cloning bootstrap repository to $BOOTSTRAP_DIR"
    git clone https://github.com/codeAnthem/dps_bootstrap.git "$BOOTSTRAP_DIR"
    cd "$BOOTSTRAP_DIR"
    exec ./bootstrap.sh "$@"
fi

# Get script directory for sourcing libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper libraries
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"
# shellcheck source=./lib/disk-setup.sh
source "$SCRIPT_DIR/lib/disk-setup.sh"
# shellcheck source=./lib/network-setup.sh
source "$SCRIPT_DIR/lib/network-setup.sh"
# shellcheck source=./lib/nix-setup.sh
source "$SCRIPT_DIR/lib/nix-setup.sh"


# =============================================================================
# MODE SELECTION
# =============================================================================
select_mode() {
    echo
    echo "==============================================================================="
    echo "                    DPS Bootstrap - Mode Selection"
    echo "==============================================================================="
    echo
    echo "Choose deployment mode:"
    echo "  1) Deploy VM    - Management and deployment hub"
    echo "  2) Managed Node - Infrastructure node (server, workstation, etc.)"
    echo
    
    local choice
    while true; do
        read -p "Select mode [1-2]: " choice
        case "$choice" in
            1) echo "deploy"; return 0 ;;
            2) echo "node"; return 0 ;;
            *) echo "Please select 1 or 2." ;;
        esac
    done
}


# =============================================================================
# CONFIGURATION SETUP
# =============================================================================
setup_deploy_defaults() {
    # Deploy VM defaults
    export DPS_HOSTNAME="${DPS_HOSTNAME:-deploy-01}"
    export DPS_NETWORK_METHOD="${DPS_NETWORK_METHOD:-dhcp}"
    export DPS_NETWORK_GATEWAY="${DPS_NETWORK_GATEWAY:-192.168.1.1}"
    export DPS_ENCRYPTION="${DPS_ENCRYPTION:-y}"
    export DPS_DISK_TARGET="${DPS_DISK_TARGET:-/dev/sda}"
    export DPS_ADMIN_USER="${DPS_ADMIN_USER:-admin}"
}

setup_node_defaults() {
    # Managed node defaults
    export DPS_HOSTNAME="${DPS_HOSTNAME:-}"
    export DPS_ROLE="${DPS_ROLE:-}"
    export DPS_IP_ADDRESS="${DPS_IP_ADDRESS:-}"
    export DPS_NETWORK_GATEWAY="${DPS_NETWORK_GATEWAY:-192.168.1.1}"
    export DPS_NETWORK_DNS_PRIMARY="${DPS_NETWORK_DNS_PRIMARY:-1.1.1.1}"
    export DPS_NETWORK_DNS_SECONDARY="${DPS_NETWORK_DNS_SECONDARY:-1.0.0.1}"
    export DPS_ENCRYPTION="${DPS_ENCRYPTION:-n}"
    export DPS_DISK_TARGET="${DPS_DISK_TARGET:-/dev/sda}"
    export DPS_ADMIN_USER="${DPS_ADMIN_USER:-admin}"
}


# =============================================================================
# DEPLOY VM WORKFLOW
# =============================================================================
deploy_vm_workflow() {
    log "Starting Deploy VM workflow"
    
    # Setup defaults and validate
    setup_deploy_defaults
    validate_deploy_config
    
    # Show configuration and get confirmation
    show_configuration_preview "deploy"
    
    # Get GitHub token for private repo access
    local github_token
    github_token=$(prompt_github_token)
    
    # Setup encryption if enabled
    setup_encryption "$DPS_ENCRYPTION"
    
    # Partition and mount disk
    partition_disk "$DPS_ENCRYPTION"
    mount_filesystems "$DPS_ENCRYPTION"
    
    # Generate hardware config
    generate_hardware_config "$DPS_HOSTNAME"
    
    # Create Deploy VM configuration
    create_deploy_vm_config "$DPS_HOSTNAME" "$DPS_ENCRYPTION"
    
    # Install NixOS (no flake needed for Deploy VM)
    install_deploy_vm "$DPS_HOSTNAME"
    
    success "Deploy VM installation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Reboot the system"
    echo "2. Clone your private repository with write access"
    echo "3. Set up SOPS keys and SSH keys for cluster management"
    echo "4. Use deployment tools to create managed nodes"
}


# =============================================================================
# MANAGED NODE WORKFLOW
# =============================================================================
managed_node_workflow() {
    log "Starting Managed Node workflow"
    
    # Setup defaults and validate
    setup_node_defaults
    
    # Prompt for required values if not set
    [[ -z "$DPS_ROLE" ]] && read -p "Enter node role (worker/gateway/gpu-worker): " DPS_ROLE
    [[ -z "$DPS_HOSTNAME" ]] && read -p "Enter hostname: " DPS_HOSTNAME
    [[ -z "$DPS_IP_ADDRESS" ]] && read -p "Enter IP address: " DPS_IP_ADDRESS
    
    # Export the values
    export DPS_ROLE DPS_HOSTNAME DPS_IP_ADDRESS
    
    validate_node_config
    
    # Show configuration and get confirmation
    show_configuration_preview "node"
    
    # Get GitHub token and private repo URL
    local github_token
    github_token=$(prompt_github_token)
    
    local private_repo
    read -p "Enter your private NixOS flake repository URL: " private_repo
    
    # Setup encryption if enabled
    setup_encryption "$DPS_ENCRYPTION"
    
    # Partition and mount disk
    partition_disk "$DPS_ENCRYPTION"
    mount_filesystems "$DPS_ENCRYPTION"
    
    # Clone private repository
    local private_repo_path="/mnt/etc/nixos-flake"
    clone_repository "$private_repo" "$private_repo_path" "$github_token"
    
    # Generate hardware config
    generate_hardware_config "$DPS_HOSTNAME"
    
    # Create node configuration
    create_node_config "$DPS_ROLE" "$DPS_HOSTNAME" "$DPS_ENCRYPTION" "$private_repo_path"
    
    # Install NixOS with flake and hardware override
    install_managed_node "$DPS_HOSTNAME" "$private_repo_path"
    
    success "Managed node installation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Reboot the system"
    echo "2. Node will automatically pull configurations from private repository"
    echo "3. Use 'dps-update' command to update system configuration"
    echo "4. Verify connectivity with Deploy VM"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================
main() {
    echo
    echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Setup runtime environment
    setup_runtime
    setup_cleanup
    
    # Select deployment mode
    local mode
    mode=$(select_mode)
    
    log "Selected mode: $mode"
    
    # Run appropriate workflow
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
    if [[ "${DPS_ENCRYPTION:-}" == "y" && -n "${DPS_KEY_FILE:-}" ]]; then
        echo
        echo "IMPORTANT: Encryption key saved to: ${DPS_KEY_FILE}"
        echo "Make sure to backup this key before rebooting!"
    fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
main "$@"
