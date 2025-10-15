#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Common Helper Functions
# ==================================================================================================

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Logging functions (one-liners with printf for performance)
log() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [INFO] $*" >&2; }
error() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [ERROR] $*" >&2; exit 1; }
warning() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [WARN] $*" >&2; }
success() { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [SUCCESS] $*" >&2; }
debug() { [[ "${DPS_DEBUG:-}" == "1" ]] && { printf -v t '%(%Y-%m-%d %H:%M:%S)T' -1; echo "[$t] [DEBUG] $*" >&2; }; }

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup() {
    if [[ -d "${RUNTIME_DIR:-}" ]]; then
        log "Cleaning up runtime directory: $RUNTIME_DIR"
        rm -rf "$RUNTIME_DIR"
    fi
}


# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

# Reusable input functions
prompt_yes_no() {
    local prompt="$1"
    local response
    local default_yes="${2:-false}"
    
    # Read from terminal directly to avoid stdin pollution
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -p "$prompt [y/N]: " response
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            echo "$prompt [y/N]: "
            read response < /dev/tty || {
                if [[ "$default_yes" == "true" ]]; then
                    echo "No input received, assuming 'yes'"
                    return 0
                else
                    echo "No input received, assuming 'no'"
                    return 1
                fi
            }
        else
            # No TTY available, use default
            if [[ "$default_yes" == "true" ]]; then
                echo "No interactive terminal available, assuming 'yes'"
                return 0
            else
                echo "No interactive terminal available, assuming 'no'"
                return 1
            fi
        fi
    fi
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]|"") return 1 ;;
        *) 
            echo "Invalid response '$response', assuming 'no'"
            return 1 ;;
    esac
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
    
    # Read from terminal directly to avoid stdin pollution
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -s -p "Enter GitHub token (or press Enter to use anonymous access): " token
        echo
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            echo "Enter GitHub token (or press Enter to use anonymous access): "
            read -s token < /dev/tty || {
                echo "No input received, using anonymous access"
                token=""
            }
            echo
        else
            # No TTY available, use anonymous access
            echo "No interactive terminal available, using anonymous access"
            token=""
        fi
    fi
    
    if [[ -n "$token" ]]; then
        echo "Token received (hidden for security)"
    else
        echo "Using anonymous access (limited functionality)"
    fi
    
    echo "$token"
    return 0
}

# =============================================================================
# RUNTIME SETUP
# =============================================================================

setup_runtime() {
    # Runtime directory with printf for performance
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    readonly RUNTIME_ID="dps_${timestamp}_$$"
    readonly RUNTIME_DIR="/tmp/${RUNTIME_ID}"
    
    # Create runtime directory
    mkdir -p "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"
    
    log "Runtime directory: $RUNTIME_DIR"
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
# CONFIGURATION PREVIEW
# =============================================================================

show_configuration_preview() {
    local mode="$1"
    
    echo
    echo "==============================================================================="
    echo "                           CONFIGURATION PREVIEW"
    echo "==============================================================================="
    echo
    echo "Mode: $mode"
    echo
    
    if [[ "$mode" == "deploy" ]]; then
        show_deploy_config
    else
        show_node_config
    fi
    
    echo "==============================================================================="
    echo
    
    # Auto-confirm after timeout if needed
    if prompt_yes_no "Proceed with this configuration?" true; then
        echo "Configuration confirmed!"
    else
        error "Configuration not confirmed. Exiting."
    fi
}

show_deploy_config() {
    echo "Deploy VM Configuration:"
    echo "  Hostname                        = ${DPS_HOSTNAME:-[not set]}"
    echo "  Network Method                  = ${DPS_NETWORK_METHOD:-dhcp}"
    echo "  IP Address                      = ${DPS_IP_ADDRESS:-[dhcp]}"
    echo "  Network Gateway                 = ${DPS_NETWORK_GATEWAY:-192.168.1.1}"
    echo "  Encryption                      = ${DPS_ENCRYPTION:-y}"
    echo "  Disk Target                     = ${DPS_DISK_TARGET:-/dev/sda}"
    echo "  Admin User                      = ${DPS_ADMIN_USER:-admin}"
}

show_node_config() {
    echo "Managed Node Configuration:"
    echo "  Role                            = ${DPS_ROLE:-[not set]}"
    echo "  Hostname                        = ${DPS_HOSTNAME:-[not set]}"
    echo "  IP Address                      = ${DPS_IP_ADDRESS:-[not set]}"
    echo "  Network Gateway                 = ${DPS_NETWORK_GATEWAY:-192.168.1.1}"
    echo "  DNS Primary                     = ${DPS_NETWORK_DNS_PRIMARY:-1.1.1.1}"
    echo "  DNS Secondary                   = ${DPS_NETWORK_DNS_SECONDARY:-1.0.0.1}"
    echo "  Encryption                      = ${DPS_ENCRYPTION:-n}"
    echo "  Disk Target                     = ${DPS_DISK_TARGET:-/dev/sda}"
    echo "  Admin User                      = ${DPS_ADMIN_USER:-admin}"
}
