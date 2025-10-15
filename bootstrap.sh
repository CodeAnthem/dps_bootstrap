#!/usr/bin/env bash
# ==================================================================================================
# Digital Paradise Swarm - Bootstrap Script by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2024-10-15 | Modified: 2025-10-15
# Description:   Automated NixOS deployment and configuration for DPS cluster nodes
# Feature:       One-liner bootstrap with encryption, partitioning, and flake integration
# ==================================================================================================

set -euo pipefail

# =============================================================================
# SCRIPT METADATA
# =============================================================================
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="DPS Bootstrap"


# =============================================================================
# DEFAULT VALUES
# =============================================================================
# Network Defaults
readonly DEFAULT_NETWORK_GATEWAY="192.168.0.1"
readonly DEFAULT_NETWORK_MASK="255.255.255.0"
readonly DEFAULT_DNS_PRIMARY="1.1.1.1"
readonly DEFAULT_DNS_SECONDARY="1.0.0.1"

# System Defaults
readonly DEFAULT_ADMIN_USER="admin"

# Disk Defaults
readonly DEFAULT_DISK_TARGET="/dev/sda"
readonly DEFAULT_ENCRYPTION_ENABLED="n"
readonly DEFAULT_ENCRYPTION_KEY_LENGTH="32"
readonly DEFAULT_ENCRYPTION_USE_PASSPHRASE="n"
readonly DEFAULT_ENCRYPTION_PASSPHRASE_LENGTH="32"
readonly DEFAULT_ENCRYPTION_GENERATE="urandom"


# =============================================================================
# CONFIGURATION CONSTANTS
# =============================================================================
# VM Types
readonly VM_TYPES=("tooling" "gateway" "worker" "gpu-worker")

# Encryption methods
readonly ENCRYPTION_METHODS=("openssl-rand" "urandom" "manual")

# Internal paths
readonly FLAKE_PATH="/etc/nixos-flake"

# Runtime directory with printf for performance
printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
readonly RUNTIME_ID="dps_${timestamp}_$$"
readonly RUNTIME_DIR="/tmp/${RUNTIME_ID}"


# =============================================================================
# FINAL CONFIGURATION VARIABLES
# =============================================================================
# Network Configuration
readonly CONFIG_NETWORK_GATEWAY="${DPS_NETWORK_GATEWAY:-$DEFAULT_NETWORK_GATEWAY}"
readonly CONFIG_NETWORK_MASK="${DPS_NETWORK_MASK:-$DEFAULT_NETWORK_MASK}"
readonly CONFIG_DNS_PRIMARY="${DPS_NETWORK_DNS_PRIMARY:-$DEFAULT_DNS_PRIMARY}"
readonly CONFIG_DNS_SECONDARY="${DPS_NETWORK_DNS_SECONDARY:-$DEFAULT_DNS_SECONDARY}"

# System Configuration
readonly CONFIG_ADMIN_USER="${DPS_ADMIN_USER:-$DEFAULT_ADMIN_USER}"

# Disk Configuration
readonly CONFIG_DISK_TARGET="${DPS_DISK_TARGET:-$DEFAULT_DISK_TARGET}"
readonly CONFIG_ENCRYPTION_ENABLED="${DPS_DISK_ENCRYPTION_ENABLED:-$DEFAULT_ENCRYPTION_ENABLED}"
readonly CONFIG_ENCRYPTION_KEY_LENGTH="${DPS_DISK_ENCRYPTION_KEY_LENGTH:-$DEFAULT_ENCRYPTION_KEY_LENGTH}"
readonly CONFIG_ENCRYPTION_USE_PASSPHRASE="${DPS_DISK_ENCRYPTION_USE_PASSPHRASE:-$DEFAULT_ENCRYPTION_USE_PASSPHRASE}"
readonly CONFIG_ENCRYPTION_PASSPHRASE_LENGTH="${DPS_DISK_ENCRYPTION_PASSPHRASE_LENGTH:-$DEFAULT_ENCRYPTION_PASSPHRASE_LENGTH}"
readonly CONFIG_ENCRYPTION_GENERATE="${DPS_DISK_ENCRYPTION_GENERATE:-$DEFAULT_ENCRYPTION_GENERATE}"

# Required user-provided variables (no defaults)
readonly CONFIG_GIT_REPO="${DPS_GIT_REPO:-}"
readonly CONFIG_NETWORK_HOSTNAME="${DPS_NETWORK_HOSTNAME:-}"
readonly CONFIG_NETWORK_ADDRESS="${DPS_NETWORK_ADDRESS:-}"
readonly CONFIG_ROLE="${DPS_ROLE:-}"


# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================
# Check required environment variables
required_vars=(
    "DPS_NETWORK_HOSTNAME"
    "DPS_NETWORK_ADDRESS"
    "DPS_ROLE"
    "DPS_GIT_REPO"
)

validate_required_config() {
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "ERROR: Required environment variables not set:" >&2
        printf "  %s\n" "${missing_vars[@]}" >&2
        echo "Please set all required variables before running this script" >&2
        exit 1
    fi
}


# =============================================================================
# CONFIGURATION PREVIEW
# =============================================================================
show_configuration_preview() {
    echo
    echo "==============================================================================="
    echo "                           CONFIGURATION PREVIEW"
    echo "==============================================================================="
    echo
    echo "Repository Configuration:"
    echo "  CONFIG_GIT_REPO                     = $CONFIG_GIT_REPO"
    echo
    echo "Network Configuration:"
    echo "  CONFIG_NETWORK_HOSTNAME         = $CONFIG_NETWORK_HOSTNAME"
    echo "  CONFIG_NETWORK_ADDRESS          = $CONFIG_NETWORK_ADDRESS"
    echo "  CONFIG_NETWORK_GATEWAY          = $CONFIG_NETWORK_GATEWAY"
    echo "  CONFIG_NETWORK_MASK             = $CONFIG_NETWORK_MASK"
    echo "  CONFIG_DNS_PRIMARY              = $CONFIG_DNS_PRIMARY"
    echo "  CONFIG_DNS_SECONDARY            = $CONFIG_DNS_SECONDARY"
    echo
    echo "System Configuration:"
    echo "  CONFIG_ROLE                     = $CONFIG_ROLE"
    echo "  CONFIG_ADMIN_USER               = $CONFIG_ADMIN_USER"
    echo
    echo "Disk Configuration:"
    echo "  CONFIG_DISK_TARGET              = $CONFIG_DISK_TARGET"
    echo "  CONFIG_ENCRYPTION_ENABLED       = $CONFIG_ENCRYPTION_ENABLED"
    echo "  CONFIG_ENCRYPTION_KEY_LENGTH    = $CONFIG_ENCRYPTION_KEY_LENGTH"
    echo "  CONFIG_ENCRYPTION_USE_PASSPHRASE = $CONFIG_ENCRYPTION_USE_PASSPHRASE"
    echo "  CONFIG_ENCRYPTION_PASSPHRASE_LENGTH = $CONFIG_ENCRYPTION_PASSPHRASE_LENGTH"
    echo "  CONFIG_ENCRYPTION_GENERATE      = $CONFIG_ENCRYPTION_GENERATE"
    echo
    echo "Runtime Information:"
    echo "  RUNTIME_ID                      = $RUNTIME_ID"
    echo "  RUNTIME_DIR                     = $RUNTIME_DIR"
    echo
    echo "==============================================================================="
    echo

    prompt_yes_no "Proceed with this configuration?" || error "Configuration not confirmed. Exiting."
}


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
# Logging functions (one-liners)
log() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [INFO] $*" >&2; }
error() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [ERROR] $*" >&2; exit 1; }
warning() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [WARN] $*" >&2; }
success() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [SUCCESS] $*" >&2; }
debug() { [[ "${DPS_DEBUG:-}" == "1" ]] && { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [DEBUG] $*" >&2; }; }

cleanup() {
    if [[ -d "$RUNTIME_DIR" ]]; then
        log "Cleaning up runtime directory: $RUNTIME_DIR"
        rm -rf "$RUNTIME_DIR"
    fi
}

trap cleanup EXIT

# Reusable input functions
prompt_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt [y/N]: " response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

prompt_password() {
    local prompt="$1"
    local password
    local confirm_password
    while true; do
        read -s -p "$prompt: " password
        echo
        read -s -p "Confirm $prompt: " confirm_password
        echo
        if [[ "$password" == "$confirm_password" ]]; then
            echo "$password"
            return 0
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

prompt_github_token() {
    local token
    while true; do
        read -s -p "Enter GitHub token: " token
        echo
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        else
            echo "GitHub token cannot be empty. Please try again."
        fi
    done
}


# =============================================================================
# NIX SHELL WRAPPER
# =============================================================================
with_nix_shell() {
    local packages="$1"
    shift
    debug "Running with nix-shell packages: $packages"
    nix-shell -p $packages --run "$*"
}


# =============================================================================
# KEY GENERATION FUNCTIONS
# =============================================================================
generate_age_key() {
    local key_file="$1"
    log "Generating Age key: $key_file"

    mkdir -p "$(dirname "$key_file")"
    with_nix_shell "age" "age-keygen -o '$key_file'"
    chmod 600 "$key_file"

    # Extract public key
    local public_key
    public_key=$(grep "public key:" "$key_file" | cut -d: -f2 | tr -d ' ')
    echo "$public_key"
}

generate_ssh_key() {
    local key_file="$1"
    local passphrase="$2"
    log "Generating SSH key: $key_file"

    mkdir -p "$(dirname "$key_file")"

    if [[ -n "$passphrase" ]]; then
        with_nix_shell "openssh" "ssh-keygen -t ed25519 -f '$key_file' -N '$passphrase' -C 'dps-admin@$DPS_NETWORK_HOSTNAME'"
    else
        with_nix_shell "openssh" "ssh-keygen -t ed25519 -f '$key_file' -N '' -C 'dps-admin@$DPS_NETWORK_HOSTNAME'"
    fi

    chmod 600 "$key_file"
    chmod 644 "${key_file}.pub"

    # Return public key
    cat "${key_file}.pub"
}


# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================
validate_vm_type() {
    local vm_type="$1"
    for valid_type in "${VM_TYPES[@]}"; do
        if [[ "$vm_type" == "$valid_type" ]]; then
            return 0
        fi
    done
    return 1
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

validate_hostname() {
    local hostname="$1"
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 0
    fi
    return 1
}


# =============================================================================
# ENCRYPTION FUNCTIONS
# =============================================================================
generate_encryption_key() {
    local method="$1"
    local length="$2"
    local passphrase="$3"

    local key=""

    case "$method" in
        "openssl-rand")
            key=$(with_nix_shell "openssl" "openssl rand -base64 '$length'")
            ;;
        "urandom")
            key=$(head -c "$length" /dev/urandom | base64 -w 0)
            ;;
        "manual")
            read -s -p "Enter encryption key: " key
            echo
            ;;
        *)
            error "Unknown encryption method: $method. Valid: ${ENCRYPTION_METHODS[*]}"
            ;;
    esac

    if [[ -n "$passphrase" ]]; then
        # Combine key with passphrase using PBKDF2
        key=$(with_nix_shell "openssl" "echo -n '$key' | openssl dgst -sha256 -pbkdf2 -iter 100000 -pass pass:'$passphrase' | cut -d' ' -f2")
    fi

    echo "$key"
}

setup_encryption() {
    local use_encryption="$1"

    if [[ "$use_encryption" != "y" ]]; then
        return 0
    fi

    echo
    echo "=== Encryption Configuration ==="

    log "Using encryption method: $CONFIG_ENCRYPTION_GENERATE with key length: $CONFIG_ENCRYPTION_KEY_LENGTH bytes"

    if [[ ! "$CONFIG_ENCRYPTION_KEY_LENGTH" =~ ^[1-9][0-9]*$ ]] || [[ "$CONFIG_ENCRYPTION_KEY_LENGTH" -lt 16 ]] || [[ "$CONFIG_ENCRYPTION_KEY_LENGTH" -gt 128 ]]; then
        error "Key length must be between 16 and 128 bytes"
    fi

    # Passphrase handling
    local passphrase=""
    if [[ "$CONFIG_ENCRYPTION_USE_PASSPHRASE" == "y" ]]; then
        passphrase=$(prompt_password "Enter passphrase")
    fi

    # Generate key
    log "Generating encryption key"
    local encryption_key
    encryption_key=$(generate_encryption_key "$CONFIG_ENCRYPTION_GENERATE" "$CONFIG_ENCRYPTION_KEY_LENGTH" "$passphrase")

    # Save to runtime directory
    local key_file="$RUNTIME_DIR/encryption-key.txt"
    echo "$encryption_key" > "$key_file"
    chmod 600 "$key_file"

    echo
    echo "=== CRITICAL: BACKUP THIS ENCRYPTION KEY ==="
    echo "Key: $encryption_key"
    echo "Saved to: $key_file"
    echo "Method: $CONFIG_ENCRYPTION_GENERATE (${CONFIG_ENCRYPTION_KEY_LENGTH} bytes)"
    if [[ -n "$passphrase" ]]; then
        echo "Passphrase: [PROTECTED]"
    fi
    echo "=============================================="
    echo

    prompt_yes_no "Have you backed up the encryption key?" || error "Please backup the encryption key before continuing"

    export DPS_ENCRYPTION_KEY="$encryption_key"
    export DPS_KEY_FILE="$key_file"
}


# =============================================================================
# DISK SETUP FUNCTIONS
# =============================================================================
partition_disk() {
    local use_encryption="$1"
    local disk="$CONFIG_DISK_TARGET"

    # Check if disk exists
    if [[ ! -b "$disk" ]]; then
        error "Target disk does not exist: $disk"
    fi

    log "Partitioning disk: $disk"

    # Create partition table
    parted "$disk" --script -- mklabel gpt
    parted "$disk" --script -- mkpart ESP fat32 1MiB 512MiB
    parted "$disk" --script -- set 1 esp on
    parted "$disk" --script -- mkpart primary 512MiB 100%

    # Format boot partition
    mkfs.fat -F 32 -n boot "${disk}1"

    if [[ "$use_encryption" == "y" ]]; then
        setup_encrypted_root "${disk}2"
    else
        setup_standard_root "${disk}2"
    fi
}

setup_encrypted_root() {
    local partition="$1"

    log "Setting up encrypted root partition"

    if [[ -z "${DPS_ENCRYPTION_KEY:-}" ]]; then
        error "Encryption key not available"
    fi

    # Setup LUKS
    echo -n "$DPS_ENCRYPTION_KEY" | cryptsetup luksFormat --type luks2 "$partition" -
    echo -n "$DPS_ENCRYPTION_KEY" | cryptsetup open "$partition" cryptroot -

    # Format encrypted partition
    mkfs.ext4 -L nixos /dev/mapper/cryptroot
}

setup_standard_root() {
    local partition="$1"

    log "Setting up standard root partition"
    mkfs.ext4 -L nixos "$partition"
}

mount_filesystems() {
    local use_encryption="$1"

    log "Mounting filesystems"

    if [[ "$use_encryption" == "y" ]]; then
        mount /dev/mapper/cryptroot /mnt
    else
        mount /dev/disk/by-label/nixos /mnt
    fi

    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
}


# =============================================================================
# NIXOS SETUP FUNCTIONS
# =============================================================================
clone_repository() {
    local github_token="$1"

    log "Cloning repository: $CONFIG_GIT_REPO"

    # Setup git credentials
    git config --global credential.helper store
    echo "https://token:${github_token}@github.com" > ~/.git-credentials

    # Clone repository
    mkdir -p "/mnt$FLAKE_PATH"
    git clone "$CONFIG_GIT_REPO" "/mnt$FLAKE_PATH"

    # Cleanup credentials
    rm -f ~/.git-credentials
    git config --global --unset credential.helper
}

generate_hardware_config() {
    local hostname="$1"

    log "Generating hardware configuration"

    # Generate hardware config locally (stays in /etc/nixos/)
    nixos-generate-config --root /mnt --dir /mnt/etc/nixos

    # Hardware config stays local, never moved to flake repository
    log "Hardware configuration generated at /mnt/etc/nixos/hardware-configuration.nix"
}

create_host_config() {
    local vm_role="$1"
    local hostname="$2"
    local ip_address="$3"
    local use_encryption="$4"

    log "Creating host-specific configuration"

    # Create local configuration that imports role template from flake
    cat > "/mnt/etc/nixos/configuration.nix" << EOF
# $hostname - Generated by DPS Bootstrap
{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware config (local only)
    ./hardware-configuration.nix
    # Role template from flake repository
    $FLAKE_PATH/templates/${vm_role}.nix
  ];

  networking = {
    hostName = "$hostname";
    interfaces.eth0.ipv4.addresses = [{
      address = "$ip_address";
      prefixLength = 24;
    }];
    defaultGateway = "$CONFIG_NETWORK_GATEWAY";
    nameservers = [ "$CONFIG_DNS_PRIMARY" "$CONFIG_DNS_SECONDARY" ];
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootstrap phase marker
  environment.etc."bootstrap-phase".text = "true";

  # Encryption settings
  homelab.encryption.enable = $([ "$use_encryption" == "y" ] && echo "true" || echo "false");

  system.stateVersion = "$(nixos-version | cut -d. -f1-2)";
}
EOF

    # Create dps-update script for this VM
    cat > "/mnt/usr/local/bin/dps-update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "🔄 Updating DPS Swarm configuration..."

cd /etc/nixos-flake
git pull origin main

echo "🔧 Rebuilding system configuration..."
nixos-rebuild switch \
  --flake .#default \
  --override-input hardware "path:/etc/nixos/hardware-configuration.nix"

echo "✅ Update complete!"
EOF

    mkdir -p "/mnt/usr/local/bin"
    chmod +x "/mnt/usr/local/bin/dps-update"
}

install_nixos() {
    local hostname="$1"

    log "Installing NixOS with hardware override"

    # Install using default configuration with hardware override
    nixos-install --no-root-passwd \
      --flake "/mnt$FLAKE_PATH#default" \
      --override-input hardware "path:/mnt/etc/nixos/hardware-configuration.nix"
}


# =============================================================================
# MAIN FUNCTIONS
# =============================================================================
validate_configuration() {
    echo
    echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
    echo

    # Create runtime directory
    mkdir -p "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"

    # Validate VM role
    if ! validate_vm_type "$CONFIG_ROLE"; then
        error "Invalid VM role: $CONFIG_ROLE. Must be one of: ${VM_TYPES[*]}"
    fi

    # Validate hostname
    if ! validate_hostname "$CONFIG_NETWORK_HOSTNAME"; then
        error "Invalid hostname format: $CONFIG_NETWORK_HOSTNAME"
    fi

    # Validate IP address
    if ! validate_ip "$CONFIG_NETWORK_ADDRESS"; then
        error "Invalid IP address format: $CONFIG_NETWORK_ADDRESS"
    fi

    # Disk existence will be checked in partition_disk function

    # Validate encryption setting
    if [[ "$CONFIG_ENCRYPTION_ENABLED" != "y" && "$CONFIG_ENCRYPTION_ENABLED" != "n" ]]; then
        error "Encryption setting must be 'y' or 'n', got: $CONFIG_ENCRYPTION_ENABLED"
    fi

    # Configuration Preview
    show_configuration_preview
}

main() {
    log "Starting DPS Bootstrap"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi

    # Validate required configuration
    validate_required_config

    # Validate and show configuration
    validate_configuration

    # Get GitHub token interactively (not stored in env vars)
    local github_token
    github_token=$(prompt_github_token)

    # Setup encryption if needed
    setup_encryption "$CONFIG_ENCRYPTION_ENABLED"

    # Partition and mount disk
    partition_disk "$CONFIG_ENCRYPTION_ENABLED"
    mount_filesystems "$CONFIG_ENCRYPTION_ENABLED"

    # Clone repository and setup NixOS
    clone_repository "$github_token"
    generate_hardware_config "$CONFIG_NETWORK_HOSTNAME"
    create_host_config "$CONFIG_ROLE" "$CONFIG_NETWORK_HOSTNAME" "$CONFIG_NETWORK_ADDRESS" "$CONFIG_ENCRYPTION_ENABLED"

    # Install NixOS
    install_nixos "$CONFIG_NETWORK_HOSTNAME"

    success "Installation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Reboot the system"
    echo "2. Use tooling VM to complete configuration with secrets"
    echo "3. Remove bootstrap phase marker when ready"

    if [[ "$CONFIG_ENCRYPTION_ENABLED" == "y" ]]; then
        echo
        echo "IMPORTANT: Encryption key saved to: ${DPS_KEY_FILE}"
        echo "Make sure to backup this key before rebooting!"
    fi
}


# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
main "$@"
