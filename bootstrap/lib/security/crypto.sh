#!/usr/bin/env bash
# ==================================================================================================
# NDS - Security - Cryptographic key generation
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-06-29
# Description:   LUKS keys, SSH/Age keypairs, passphrases (install-time secrets, not UI)
# ==================================================================================================

# =============================================================================
# NIX-SHELL HELPER
# =============================================================================

with_nix_shell() {
    local packages="$1"
    shift
    debug "Running with nix-shell packages: $packages"
    nix-shell -p "$packages" --run "$*"
}

# =============================================================================
# KEY GENERATION
# =============================================================================

generate_key_urandom() {
    local length="${1:-32}"
    dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | base64 -w 0
}

generate_key_openssl() {
    local length="${1:-32}"
    openssl rand -base64 "$length"
}

generate_key_hex() {
    local length="${1:-64}"
    dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | xxd -p -c "$length"
}

generate_passphrase_urandom() {
    local length="${1:-32}"
    dd if=/dev/urandom bs=1 count="$((length * 3 / 4))" 2>/dev/null | base64 | tr -d '\n=' | head -c "$length"
}

generate_passphrase_openssl() {
    local length="${1:-32}"
    openssl rand -base64 "$((length * 3 / 4))" | tr -d '\n=' | head -c "$length"
}

generate_passphrase_words() {
    local word_count="${1:-6}"
    local dict_file="/usr/share/dict/words"

    if [[ ! -f "$dict_file" ]]; then
        error "Dictionary file not found: $dict_file"
        return 1
    fi

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

    local passphrase=""
    local i random_index
    for ((i = 0; i < word_count; i++)); do
        random_index=$((RANDOM % ${#words[@]}))
        [[ -n "$passphrase" ]] && passphrase+="-"
        passphrase+="${words[$random_index]}"
    done

    echo "$passphrase"
}

generate_pin() {
    local length="${1:-6}"
    dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | od -An -tu1 | tr -d ' \n' | head -c "$length"
}

generate_password() {
    local length="${1:-16}"
    LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+{}|:<>?=' < /dev/urandom | head -c "$length"
}

generate_password_alnum() {
    local length="${1:-16}"
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

validate_entropy() {
    local string="$1"
    local min_bits="${2:-64}"
    local charset_size=0

    [[ "$string" =~ [a-z] ]] && ((charset_size += 26))
    [[ "$string" =~ [A-Z] ]] && ((charset_size += 26))
    [[ "$string" =~ [0-9] ]] && ((charset_size += 10))
    [[ "$string" =~ [^a-zA-Z0-9] ]] && ((charset_size += 32))

    [[ "$charset_size" -eq 0 ]] && return 1

    local length=${#string}
    local entropy
    entropy=$(awk "BEGIN { print int($length * log($charset_size) / log(2)) }")
    [[ "$entropy" -ge "$min_bits" ]]
}

nds_crypto_show_secret() {
    local secret="$1"
    local output_file="${2:-}"

    nds_ui_b ""
    nds_ui_h "Generated secret"
    nds_ui_b "$secret"
    nds_ui_b ""
    warn "Copy this secret now — it will not be shown again"

    if [[ -n "$output_file" ]]; then
        echo "$secret" > "$output_file"
        chmod 600 "$output_file"
        success "Secret saved to: $output_file (permissions: 600)"
    fi

    nds_ui_b ""
}

secure_clear_var() {
    local var_name="$1"
    eval "$var_name=''"
    unset "$var_name"
}

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
    cat "${key_file}.pub"
}

generate_age_key() {
    local key_file="$1"
    log "Generating Age key: $key_file"

    mkdir -p "$(dirname "$key_file")"
    with_nix_shell "age" "age-keygen -o '$key_file'"
    chmod 600 "$key_file"

    grep "public key:" "$key_file" | cut -d: -f2 | tr -d ' '
}
