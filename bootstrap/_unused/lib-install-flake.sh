#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-03
# Description:   Shared flake helpers for installFlake + remoteAction actions
# Feature:       Prepare flake env, detect disko strategy, find a flake's action script
# ==================================================================================================

# Description: Export NDS_FLAKE_* env vars from the configurator answers so the
# install pipeline (nds_nixos_install_flake) can read them. Also mirrors the
# chosen host into NETWORK_HOSTNAME. Pass a source ("remote"|"local") to override
# FLAKE_SOURCE — remoteAction always uses "remote".
# Arguments:
# - source: <String|optional> "remote" | "local" (default: read FLAKE_SOURCE)
nds_flake_prepare() {
    local source="${1:-}"

    local host repo_url local_path install_path host_dir hw_placement disk_strategy install_mode target_ip
    host=$(nds_configurator_config_get "FLAKE_HOST")
    repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")
    local_path=$(nds_configurator_config_get "FLAKE_LOCAL_PATH")

    # Derive source from whichever location field is populated (robust to env
    # overrides and the auto-detecting single-location prompt).
    if [[ -z "$source" || "$source" == "none" ]]; then
        if [[ -n "$repo_url" ]]; then source="remote"
        elif [[ -n "$local_path" ]]; then source="local"
        else source="$(nds_configurator_config_get "FLAKE_SOURCE")"; fi
        [[ -z "$source" ]] && source="remote"
    fi
    install_path=$(nds_configurator_config_get "FLAKE_INSTALL_PATH")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    hw_placement=$(nds_configurator_config_get "FLAKE_HARDWARE_PLACEMENT")
    disk_strategy=$(nds_config_get "disk" "DISK_STRATEGY")
    install_mode=$(nds_configurator_config_get "INSTALL_MODE")
    target_ip=$(nds_configurator_config_get "REMOTE_TARGET_IP")

    nds_configurator_config_set "NETWORK_HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"
    export NDS_FLAKE_SOURCE="$source"
    export NDS_FLAKE_REPO_URL="$repo_url"
    export NDS_FLAKE_LOCAL_PATH="$local_path"
    export NDS_FLAKE_INSTALL_PATH="$install_path"
    export NDS_FLAKE_HOST_DIR="$host_dir"
    export NDS_HARDWARE_PLACEMENT="$hw_placement"
    export NDS_DISK_STRATEGY="$disk_strategy"
    export NDS_INSTALL_MODE="${install_mode:-local}"
    export NDS_REMOTE_TARGET_IP="$target_ip"

    log "Flake target: ${install_path}#${host} (source: ${source}, mode: ${NDS_INSTALL_MODE})"
}

# Description: Inspect the flake (local path or remote clone) and apply a disko
# disk strategy if the flake declares one. Best-effort — silently skips when no
# disko config is found or the source is unavailable.
nds_flake_detect_disko() {
    local host host_dir local_path repo_url probe_root
    host=$(nds_configurator_config_get "FLAKE_HOST")
    host_dir=$(nds_configurator_config_get "FLAKE_HOST_DIR")
    host_dir="${host_dir:-hosts/x86_64-linux}"
    local_path=$(nds_configurator_config_get "FLAKE_LOCAL_PATH")
    repo_url=$(nds_configurator_config_get "FLAKE_REPO_URL")

    if [[ -n "$local_path" ]]; then
        [[ -d "$local_path" ]] && nds_preflight_apply_disko_strategy "$local_path" "$host" "$host_dir"
    elif [[ -n "$repo_url" ]]; then
        probe_root=$(nds_preflight_probe_flake "$repo_url") || return 0
        nds_preflight_apply_disko_strategy "$probe_root" "$host" "$host_dir"
    fi
}

# Description: Absolute path to the NDS install templates directory.
# Returns:
# - <String> templates dir (stdout)
_nds_templates_dir() {
    local this_dir
    this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "${this_dir}/templates"
}

# Description: Discover installable roles from a flake's profiles/ directory.
# Strips -eval variants and the .nix extension, returns a "|"-joined list.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# Returns:
# - <String> Pipe-joined role names (stdout), empty when none found
_nds_discover_roles() {
    local flake_root="$1"
    local profiles_dir="${flake_root}/profiles"

    if [[ ! -d "$profiles_dir" ]]; then
        echo ""
        return 0
    fi

    find "$profiles_dir" -maxdepth 1 -name '*.nix' -printf '%f\n' 2>/dev/null | \
        sed -e 's/-eval\.nix$//' -e 's/\.nix$//' | sort -u | tr '\n' '|' | sed 's/|$//'
}

# Description: Resolve a stable /dev/disk/by-id path for a block device, falling
# back to the raw device node when no by-id link is found.
# Arguments:
# - disk: <String> Device node (e.g. /dev/sda)
# Returns:
# - <String> Resolved device path (stdout)
_nds_disk_by_id() {
    local disk="$1"
    local target link
    [[ -z "$disk" ]] && { echo "$disk"; return 0; }
    target="$(readlink -f "$disk" 2>/dev/null || echo "$disk")"

    if [[ -d /dev/disk/by-id ]]; then
        for link in /dev/disk/by-id/*; do
            [[ -e "$link" ]] || continue
            if [[ "$(readlink -f "$link" 2>/dev/null)" == "$target" ]]; then
                echo "$link"
                return 0
            fi
        done
    fi
    echo "$disk"
}

# Description: Scaffold a new host folder (opts.nix, configuration.nix,
# disko.nix) into a flake from NDS templates using collected config values.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# - hostname:   <String> New host name
# - role:       <String> Role/profile name (from profiles/)
# - system:     <String|optional> Nix system (default: x86_64-linux)
# Returns:
# - <Int> 0 on success, non-zero on failure
_nds_scaffold_host_folder() {
    local flake_root="$1"
    local hostname="$2"
    local role="$3"
    local system="${4:-x86_64-linux}"
    local tmpl_dir host_dir
    tmpl_dir="$(_nds_templates_dir)"
    host_dir="${flake_root}/hosts/${system}/${hostname}"

    if [[ -z "$hostname" || -z "$role" ]]; then
        error "Scaffold requires a hostname and a role"
        return 1
    fi

    if [[ -d "$host_dir" ]]; then
        warn "Host folder already exists: $host_dir"
        if [[ "${NDS_AUTO_CONFIRM:-false}" != "true" ]]; then
            nds_askUserToProceed "Overwrite files in $host_dir?" || return 1
        fi
    fi

    mkdir -p "$host_dir" || { error "Cannot create $host_dir"; return 1; }

    sed "s/__ROLE__/${role}/g" \
        "${tmpl_dir}/host-opts.nix.tmpl" > "${host_dir}/opts.nix" || return 1

    local ip gateway mask prefix interface dns1 dns2 nameservers state_version method
    ip=$(nds_config_get "network" "NETWORK_IP")
    gateway=$(nds_config_get "network" "NETWORK_GATEWAY")
    mask=$(nds_config_get "network" "NETWORK_MASK")
    method=$(nds_config_get "network" "NETWORK_METHOD")
    interface=$(nds_config_get "network" "NETWORK_INTERFACE")
    interface="${interface:-eth0}"
    dns1=$(nds_config_get "network" "NETWORK_DNS_PRIMARY")
    dns2=$(nds_config_get "network" "NETWORK_DNS_SECONDARY")
    state_version="24.11"

    prefix="24"
    [[ -n "$mask" ]] && prefix="$(nds_validate_mask_to_prefix "$mask")"

    nameservers=""
    [[ -n "$dns1" ]] && nameservers="\"${dns1}\""
    [[ -n "$dns2" ]] && nameservers="${nameservers:+$nameservers }\"${dns2}\""

    sed -e "s/__HOSTNAME__/${hostname}/g" \
        -e "s/__IP__/${ip}/g" \
        -e "s/__GATEWAY__/${gateway}/g" \
        -e "s/__PREFIX__/${prefix}/g" \
        -e "s/__INTERFACE__/${interface}/g" \
        -e "s/__NAMESERVERS__/${nameservers}/g" \
        -e "s/__STATE_VERSION__/${state_version}/g" \
        "${tmpl_dir}/host-configuration.nix.tmpl" > "${host_dir}/configuration.nix" || return 1

    local disk disk_by_id fs_type swap_mib encryption enc_bool
    disk=$(nds_config_get "disk" "DISK_TARGET")
    fs_type=$(nds_config_get "disk" "DISK_FS_TYPE")
    fs_type="${fs_type:-ext4}"
    swap_mib=$(nds_config_get "disk" "DISK_SWAP_SIZE_MIB")
    swap_mib="${swap_mib:-0}"
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    enc_bool="false"
    [[ "$encryption" == "true" ]] && enc_bool="true"
    disk_by_id="$(_nds_disk_by_id "$disk")"

    sed -e "s|__DEVICE__|${disk_by_id}|g" \
        -e "s/__FSTYPE__/${fs_type}/g" \
        -e "s/__SWAPMIB__/${swap_mib}/g" \
        -e "s/__ENCRYPT__/${enc_bool}/g" \
        "${tmpl_dir}/host-disko.nix.tmpl" > "${host_dir}/disko.nix" || return 1

    log "Scaffolded host folder: $host_dir (role=${role})"
    return 0
}

# Description: Two-step host selection against a checked-out flake. Lets the
# operator reuse an existing host or scaffold a new one (pick role -> name host).
# On a new host, scaffolds the folder and switches the install to stage the
# updated checkout locally so the new files are included.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# - system:     <String|optional> Nix system (default: x86_64-linux)
# Returns:
# - <Int> 0 when a host is selected/scaffolded, 1 when no roles were found
nds_flake_scaffold_interactive() {
    local flake_root="$1"
    local system="${2:-x86_64-linux}"
    local roles hosts_dir existing default_role

    roles="$(_nds_discover_roles "$flake_root")"
    if [[ -z "$roles" ]]; then
        return 1
    fi

    hosts_dir="${flake_root}/hosts/${system}"
    existing=""
    if [[ -d "$hosts_dir" ]]; then
        existing="$(find "$hosts_dir" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
            | sort | tr '\n' '|' | sed 's/|$//')"
    fi

    nds_cfg_section_title "Host selection"

    if [[ -n "$existing" ]]; then
        nds_cfg_ask_choice SCAFFOLD_MODE "Host" "existing|new" \
            "existing=Use an existing host|new=Scaffold a new host" "existing"
    else
        nds_cfg_set SCAFFOLD_MODE "new"
    fi

    if nds_cfg_is SCAFFOLD_MODE existing; then
        local first_host
        first_host="${existing%%|*}"
        nds_cfg_ask_choice FLAKE_HOST "Existing host" "$existing" "" "$first_host"
        nds_configurator_config_set "NETWORK_HOSTNAME" "$(nds_cfg_get FLAKE_HOST)"
        export NDS_FLAKE_HOST="$(nds_cfg_get FLAKE_HOST)"
        return 0
    fi

    default_role="${roles%%|*}"
    nds_cfg_ask_choice SCAFFOLD_ROLE "Role" "$roles" "" "$default_role"
    nds_cfg_ask_hostname FLAKE_HOST "New host name" "" true

    local host role
    host="$(nds_cfg_get FLAKE_HOST)"
    role="$(nds_cfg_get SCAFFOLD_ROLE)"
    nds_configurator_config_set "NETWORK_HOSTNAME" "$host"
    export NDS_FLAKE_HOST="$host"

    _nds_scaffold_host_folder "$flake_root" "$host" "$role" "$system" || return 1

    # Stage the updated checkout locally so the new host files are installed.
    export NDS_FLAKE_SOURCE="local"
    export NDS_FLAKE_LOCAL_PATH="$flake_root"
    nds_configurator_config_set "FLAKE_SOURCE" "local"
    nds_configurator_config_set "FLAKE_LOCAL_PATH" "$flake_root"

    log "New host '${host}' scaffolded — review and commit ${flake_root}/hosts/${system}/${host}"
    return 0
}

# Description: Locate a flake's custom NDS action script, searching standard
# locations. Returns the first match.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# Returns:
# - <String> Path to the action script (stdout), exit 1 if none found
nds_flake_find_action_script() {
    local flake_root="$1"
    local candidate

    for candidate in \
        "${flake_root}/.nds/action.sh" \
        "${flake_root}/nds-action/setup.sh" \
        "${flake_root}/.nds/setup.sh"; do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}
