#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Common Helper Functions
# ==================================================================================================

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

console() { echo "$1" >&2; }
logDate() { printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "$1" "$2" >&2; }

log() { logDate "🔄" "$1"; }
error() { logDate "❌" "$1"; exit 1; }
success() { logDate "✅" "$1"; }
debug() { if [[ "${DEBUG:-}" == "1" ]]; then logDate "🐛" "$1"; fi; }

# Visual separators
section_header() {
    local title="$1"
    printf "\n"
    printf "╭─────────────────────────────────────────────────────────────────────────────╮\n"
    printf "│ %-75s │\n" "$title"
    printf "╰─────────────────────────────────────────────────────────────────────────────╯\n"
}

step_start() {
    local step="$1"
    printf "\n🚀 %s...\n" "$step"
}

step_complete() {
    local step="$1"
    printf "✅ %s completed\n" "$step"
}

# Progress spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Clear to new section (like clear but keeps history)
new_section() {
    printf "\033[2J\033[H"
}

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
# MODE SELECTION FUNCTIONS
# =============================================================================

select_mode() {
    # Select deployment mode
    console "Choose deployment mode:"
    console "  1) Deploy VM    - Management and deployment hub"
    console "  2) Managed Node - Infrastructure node (server, workstation, etc.)"
    console
    
    # Default to Deploy VM if input doesn't work
    local mode="deploy"
    local choice
    
    # Read from terminal directly to avoid stdin pollution from piped script
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -p "Select mode [1-2, default=1]: " choice
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            console "Select mode [1-2, default=1]: "
            read choice < /dev/tty || {
                console "No input received, defaulting to Deploy VM"
                choice="1"
            }
        else
            # No TTY available, default to Deploy VM
            console "No interactive terminal available, defaulting to Deploy VM"
            choice="1"
        fi
    fi

    # Handle empty input
    if [[ -z "$choice" ]]; then
        choice="1"
    fi
    
    case "$choice" in
        1|"")
            mode="deploy"
            console "Selected: Deploy VM"
            ;;
        2)
            mode="node"
            console "Selected: Managed Node"
            ;;
        *)
            console "Invalid selection '$choice', abort!"
            exit 1
            ;;
    esac

    echo "$mode"
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
    
    echo >&2
    echo "=== GitHub Token Required ===" >&2
    echo "A GitHub token is needed to clone your private NixOS flake repository." >&2
    echo "You can create one at: https://github.com/settings/tokens" >&2
    echo "Required permissions: repo (full repository access)" >&2
    echo >&2
    
    # Read from terminal directly to avoid stdin pollution
    if [[ -t 0 ]]; then
        # We have a real terminal
        read -s -p "Enter GitHub token (or press Enter to skip): " token
        echo
    else
        # No terminal (piped script), try to read from /dev/tty
        if [[ -c /dev/tty ]]; then
            echo "Enter GitHub token (or press Enter to skip): " >&2
            read -s token < /dev/tty || {
                echo "No input received, skipping token" >&2
                token=""
            }
            echo >&2
        else
            # No TTY available, skip token
            echo "No interactive terminal available, skipping token" >&2
            token=""
        fi
    fi
    
    if [[ -n "$token" ]]; then
        echo "✅ Token received (hidden for security)" >&2
    else
        echo "⚠️  No token provided - you'll need to set up repository access manually" >&2
    fi
    
    # ONLY return the token, send messages to stderr
    printf '%s' "$token"
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
    
    new_section
    section_header "Configuration Preview"
    
    printf "📋 Mode: %s\n\n" "$mode"
    
    if [[ "$mode" == "deploy" ]]; then
        show_deploy_config
    else
        show_node_config
    fi
    
    echo
    printf "╰─────────────────────────────────────────────────────────────────────────────╯\n"
    echo
    
    # Auto-confirm after timeout if needed
    if prompt_yes_no "Proceed with this configuration?" true; then
        success "Configuration confirmed!"
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
