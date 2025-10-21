#!/usr/bin/env bash
# ==================================================================================================
# File:          crypto.sh
# Description:   Cryptographic key and passphrase generation utilities
# Author:        DPS Project
# ==================================================================================================

# =============================================================================
# CRYPTOGRAPHIC KEY GENERATION
# =============================================================================

# Generate a cryptographic key using urandom (recommended)
# Usage: generate_key_urandom <length_in_bytes>
# Example: generate_key_urandom 32  # 32 bytes = 256 bits
generate_key_urandom() {
    local length="${1:-32}"
    dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | base64 -w 0
}

# Generate a cryptographic key using OpenSSL
# Usage: generate_key_openssl <length_in_bytes>
# Example: generate_key_openssl 32  # 32 bytes = 256 bits
generate_key_openssl() {
    local length="${1:-32}"
    openssl rand -base64 "$length"
}

# Generate a hexadecimal key (for LUKS, etc.)
# Usage: generate_key_hex <length_in_bytes>
# Example: generate_key_hex 64  # 64 bytes = 512 bits for LUKS
generate_key_hex() {
    local length="${1:-64}"
    dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | xxd -p -c "$length"
}

# =============================================================================
# PASSPHRASE GENERATION
# =============================================================================

# Generate a secure random passphrase using urandom (alphanumeric + symbols)
# Usage: generate_passphrase_urandom <length>
# Example: generate_passphrase_urandom 32
generate_passphrase_urandom() {
    local length="${1:-32}"
    # Use base64 which gives us A-Z, a-z, 0-9, +, /
    dd if=/dev/urandom bs=1 count="$((length * 3 / 4))" 2>/dev/null | base64 | tr -d '\n=' | head -c "$length"
}

# Generate a secure random passphrase using OpenSSL
# Usage: generate_passphrase_openssl <length>
# Example: generate_passphrase_openssl 32
generate_passphrase_openssl() {
    local length="${1:-32}"
    openssl rand -base64 "$((length * 3 / 4))" | tr -d '\n=' | head -c "$length"
}

# Generate a memorable passphrase using dictionary words (requires /usr/share/dict/words)
# Usage: generate_passphrase_words <word_count>
# Example: generate_passphrase_words 6  # "correct-horse-battery-staple-example-phrase"
generate_passphrase_words() {
    local word_count="${1:-6}"
    local dict_file="/usr/share/dict/words"
    
    if [[ ! -f "$dict_file" ]]; then
        error "Dictionary file not found: $dict_file"
        return 1
    fi
    
    # Filter to words between 4-8 characters, lowercase only
    local words=()
    while IFS= read -r word; do
        if [[ ${#word} -ge 4 && ${#word} -le 8 && "$word" =~ ^[a-z]+$ ]]; then
            words+=("$word")
        fi
    done < "$dict_file"
    
    if [[ ${#words[@]} -eq 0 ]]; then
        error "No suitable words found in dictionary"
        return 1
    fi
    
    # Select random words
    local passphrase=""
    for ((i = 0; i < word_count; i++)); do
        local random_index=$((RANDOM % ${#words[@]}))
        [[ -n "$passphrase" ]] && passphrase+="-"
        passphrase+="${words[$random_index]}"
    done
    
    echo "$passphrase"
}

# Generate a numeric PIN
# Usage: generate_pin <length>
# Example: generate_pin 6  # "482719"
generate_pin() {
    local length="${1:-6}"
    dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | od -An -tu1 | tr -d ' \n' | head -c "$length"
}

# =============================================================================
# PASSWORD GENERATION (for user accounts)
# =============================================================================

# Generate a strong password with mixed characters
# Usage: generate_password <length>
# Example: generate_password 16
generate_password() {
    local length="${1:-16}"
    # Generate from full character set: A-Z, a-z, 0-9, special chars
    LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+{}|:<>?=' < /dev/urandom | head -c "$length"
}

# Generate an alphanumeric-only password (no special characters)
# Usage: generate_password_alnum <length>
# Example: generate_password_alnum 16
generate_password_alnum() {
    local length="${1:-16}"
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# =============================================================================
# KEY/PASSPHRASE VALIDATION
# =============================================================================

# Check if a string meets minimum entropy requirements
# Usage: validate_entropy <string> <min_bits>
# Example: validate_entropy "mypassword" 64
validate_entropy() {
    local string="$1"
    local min_bits="${2:-64}"
    
    # Simple entropy calculation based on character set size and length
    local charset_size=0
    [[ "$string" =~ [a-z] ]] && ((charset_size += 26))
    [[ "$string" =~ [A-Z] ]] && ((charset_size += 26))
    [[ "$string" =~ [0-9] ]] && ((charset_size += 10))
    [[ "$string" =~ [^a-zA-Z0-9] ]] && ((charset_size += 32))
    
    if [[ "$charset_size" -eq 0 ]]; then
        return 1
    fi
    
    # Entropy = length * log2(charset_size)
    local length=${#string}
    local entropy
    entropy=$(awk "BEGIN { print int($length * log($charset_size) / log(2)) }")
    
    [[ "$entropy" -ge "$min_bits" ]]
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Display generated key/passphrase securely (optionally save to file)
# Usage: display_secret <secret> [output_file]
display_secret() {
    local secret="$1"
    local output_file="${2:-}"
    
    console ""
    console "=== Generated Secret ==="
    console "$secret"
    console "========================"
    console ""
    console "⚠️  Copy this secret NOW - it will not be shown again!"
    
    if [[ -n "$output_file" ]]; then
        echo "$secret" > "$output_file"
        chmod 600 "$output_file"
        console "✓ Secret saved to: $output_file (permissions: 600)"
    fi
    
    console ""
}

# Securely clear a variable from memory
# Usage: secure_clear_var <var_name>
secure_clear_var() {
    local var_name="$1"
    eval "$var_name=''"
    unset "$var_name"
}

# =============================================================================
# SSH KEY MANAGEMENT
# =============================================================================

# Generate SSH key pair (ed25519)
# Usage: generate_ssh_key "key_file" ["passphrase"] ["hostname"]
generate_ssh_key() {
    local key_file="$1"
    local passphrase="${2:-}"
    local hostname="${3:-$(hostname)}"
    
    log "Generating SSH key: $key_file"
    
    mkdir -p "$(dirname "$key_file")"
    
    if [[ -n "$passphrase" ]]; then
        with_nix_shell "openssh" "ssh-keygen -t ed25519 -f '$key_file' -N '$passphrase' -C 'dps-admin@$hostname'"
    else
        with_nix_shell "openssh" "ssh-keygen -t ed25519 -f '$key_file' -N '' -C 'dps-admin@$hostname'"
    fi
    
    chmod 600 "$key_file"
    chmod 644 "${key_file}.pub"
    
    # Return public key
    cat "${key_file}.pub"
}

# =============================================================================
# AGE KEY MANAGEMENT
# =============================================================================

# Generate Age key for SOPS encryption
# Usage: generate_age_key "key_file"
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

# =============================================================================
# RECOMMENDED DEFAULTS
# =============================================================================
# LUKS encryption key: 512 bits (64 bytes) - use generate_key_hex 64
# SSH keys: 256-512 bits - use generate_ssh_key
# Age keys: use generate_age_key
# Passphrases: 32+ characters or 6+ words - use generate_passphrase_urandom 32 or generate_passphrase_words 6
# User passwords: 16+ characters - use generate_password 16
# =============================================================================
