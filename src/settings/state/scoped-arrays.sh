#!/usr/bin/env bash
# ==================================================================================================
# NDS - Scoped configuration arrays (public contract)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-07-31
# Description:   declare -A NDS_FLAKE/DISK/... bridge to flat CONFIG_DATA; pasteable export
# ==================================================================================================

# Runtime mirrors (optional — filled on import/export sync). Flat CONFIG_DATA remains canonical.
declare -gA NDS_FLAKE=()
declare -gA NDS_DISK=()
declare -gA NDS_BOOT=()
declare -gA NDS_ENCRYPTION=()
declare -gA NDS_NETWORK=()
declare -gA NDS_PLATFORM=()
declare -gA NDS_ACCESS=()
declare -gA NDS_REGION=()
declare -gA NDS_SECURITY=()
declare -gA NDS_QUICK=()

# Git multi-repo maps (key = normalized SSH URL)
declare -gA NDS_GIT_METHOD=()
declare -gA NDS_GIT_KEY_PATH=()
declare -gA NDS_GIT_KEY_KIND=()

# Description: Map a flat CONFIG_DATA key to scoped array name + field (stdout: SCOPE\tFIELD).
# Returns non-zero when the key is not part of a scoped config array.
nds_cfg_scope_for_key() {
    local key="$1"
    case "$key" in
        FLAKE_*)
            printf 'FLAKE\t%s\n' "${key#FLAKE_}"
            ;;
        INSTALL_MODE|REMOTE_TARGET_IP)
            printf 'FLAKE\t%s\n' "$key"
            ;;
        DISK_*)
            printf 'DISK\t%s\n' "${key#DISK_}"
            ;;
        BOOT_*)
            printf 'BOOT\t%s\n' "${key#BOOT_}"
            ;;
        ENCRYPTION|ENCRYPTION_*)
            if [[ "$key" == "ENCRYPTION" ]]; then
                printf 'ENCRYPTION\tENABLED\n'
            else
                printf 'ENCRYPTION\t%s\n' "${key#ENCRYPTION_}"
            fi
            ;;
        NETWORK_*)
            printf 'NETWORK\t%s\n' "${key#NETWORK_}"
            ;;
        PLATFORM_*)
            printf 'PLATFORM\t%s\n' "${key#PLATFORM_}"
            ;;
        ACCESS_*)
            printf 'ACCESS\t%s\n' "${key#ACCESS_}"
            ;;
        REGION_*)
            printf 'REGION\t%s\n' "${key#REGION_}"
            ;;
        SECURITY_*)
            printf 'SECURITY\t%s\n' "${key#SECURITY_}"
            ;;
        QUICK_*)
            printf 'QUICK\t%s\n' "${key#QUICK_}"
            ;;
        *)
            return 1
            ;;
    esac
}

# Description: Inverse — SCOPE + FIELD → flat CONFIG key.
nds_cfg_flat_key_for_scope() {
    local scope="$1" field="$2"
    case "$scope" in
        FLAKE)
            case "$field" in
                INSTALL_MODE|REMOTE_TARGET_IP) printf '%s\n' "$field" ;;
                *) printf 'FLAKE_%s\n' "$field" ;;
            esac
            ;;
        DISK) printf 'DISK_%s\n' "$field" ;;
        BOOT) printf 'BOOT_%s\n' "$field" ;;
        ENCRYPTION)
            if [[ "$field" == "ENABLED" ]]; then
                printf 'ENCRYPTION\n'
            else
                printf 'ENCRYPTION_%s\n' "$field"
            fi
            ;;
        NETWORK) printf 'NETWORK_%s\n' "$field" ;;
        PLATFORM) printf 'PLATFORM_%s\n' "$field" ;;
        ACCESS) printf 'ACCESS_%s\n' "$field" ;;
        REGION) printf 'REGION_%s\n' "$field" ;;
        SECURITY) printf 'SECURITY_%s\n' "$field" ;;
        QUICK) printf 'QUICK_%s\n' "$field" ;;
        *) return 1 ;;
    esac
}

_nds_cfg_scope_array_nameref() {
    local scope="$1"
    local -n _arr_ref="$2"
    case "$scope" in
        FLAKE) _arr_ref=NDS_FLAKE ;;
        DISK) _arr_ref=NDS_DISK ;;
        BOOT) _arr_ref=NDS_BOOT ;;
        ENCRYPTION) _arr_ref=NDS_ENCRYPTION ;;
        NETWORK) _arr_ref=NDS_NETWORK ;;
        PLATFORM) _arr_ref=NDS_PLATFORM ;;
        ACCESS) _arr_ref=NDS_ACCESS ;;
        REGION) _arr_ref=NDS_REGION ;;
        SECURITY) _arr_ref=NDS_SECURITY ;;
        QUICK) _arr_ref=NDS_QUICK ;;
        *) return 1 ;;
    esac
}

# Description: Copy CONFIG_DATA scoped keys into declare -gA NDS_* mirrors.
nds_cfg_sync_store_to_scoped() {
    local key scope field arr_name mapped
    local -n _arr

    NDS_FLAKE=()
    NDS_DISK=()
    NDS_BOOT=()
    NDS_ENCRYPTION=()
    NDS_NETWORK=()
    NDS_PLATFORM=()
    NDS_ACCESS=()
    NDS_REGION=()
    NDS_SECURITY=()
    NDS_QUICK=()

    for key in "${!CONFIG_DATA[@]}"; do
        mapped="$(nds_cfg_scope_for_key "$key")" || continue
        scope="${mapped%%$'\t'*}"
        field="${mapped#*$'\t'}"
        _nds_cfg_scope_array_nameref "$scope" arr_name || continue
        local -n _sync_arr="$arr_name"
        _sync_arr["$field"]="${CONFIG_DATA[$key]}"
    done
}

# Description: Push scoped NDS_* array fields into CONFIG_DATA (scoped wins over empty).
nds_cfg_sync_scoped_to_store() {
    local scope field flat arr_name
    local -a scopes=(FLAKE DISK BOOT ENCRYPTION NETWORK PLATFORM ACCESS REGION SECURITY QUICK)

    for scope in "${scopes[@]}"; do
        _nds_cfg_scope_array_nameref "$scope" arr_name || continue
        local -n _src="$arr_name"
        for field in "${!_src[@]}"; do
            flat="$(nds_cfg_flat_key_for_scope "$scope" "$field")" || continue
            [[ -n "${_src[$field]:-}" ]] || continue
            CONFIG_DATA["$flat"]="${_src[$field]}"
        done
    done
}

# Description: Shell-escape a value for declare -A assignment.
_nds_cfg_shell_quote() {
    local s="$1"
    s=${s//\'/\'\\\'\'}
    printf "'%s'" "$s"
}

# Description: Emit one declare -A block for a scoped config array (stdout).
# Arguments:
# - scope: <String> FLAKE|DISK|...
# - keys:  <String...> flat CONFIG keys to include (optional filter); empty = all present
nds_cfg_export_scoped_block() {
    local scope="$1"
    shift
    local -a filter=("$@")
    local key field arr_name val mapped
    local -A want=()
    local f

    for f in "${filter[@]}"; do
        [[ -n "$f" ]] && want["$f"]=1
    done

    _nds_cfg_scope_array_nameref "$scope" arr_name || return 1

    printf 'declare -A NDS_%s=(\n' "$scope"
    for key in "${!CONFIG_DATA[@]}"; do
        mapped="$(nds_cfg_scope_for_key "$key")" || continue
        [[ "${mapped%%$'\t'*}" == "$scope" ]] || continue
        if [[ ${#want[@]} -gt 0 && -z "${want[$key]:-}" ]]; then
            continue
        fi
        field="${mapped#*$'\t'}"
        val="${CONFIG_DATA[$key]}"
        [[ -n "$val" ]] || continue
        printf '  [%s]=%s\n' "$field" "$(_nds_cfg_shell_quote "$val")"
    done
    printf ')\n'
}

# Description: Emit git URL-keyed maps as declare -A blocks.
nds_cfg_export_git_maps() {
    local url
    if [[ ${#NDS_GIT_METHOD[@]} -gt 0 ]]; then
        echo "declare -A NDS_GIT_METHOD=("
        for url in "${!NDS_GIT_METHOD[@]}"; do
            printf '  [%s]=%s\n' "$(_nds_cfg_shell_quote "$url")" \
                "$(_nds_cfg_shell_quote "${NDS_GIT_METHOD[$url]}")"
        done
        echo ")"
        echo ""
    fi
    if [[ ${#NDS_GIT_KEY_PATH[@]} -gt 0 ]]; then
        echo "declare -A NDS_GIT_KEY_PATH=("
        for url in "${!NDS_GIT_KEY_PATH[@]}"; do
            printf '  [%s]=%s\n' "$(_nds_cfg_shell_quote "$url")" \
                "$(_nds_cfg_shell_quote "${NDS_GIT_KEY_PATH[$url]}")"
        done
        echo ")"
        echo ""
    fi
    if [[ ${#NDS_GIT_KEY_KIND[@]} -gt 0 ]]; then
        echo "declare -A NDS_GIT_KEY_KIND=("
        for url in "${!NDS_GIT_KEY_KIND[@]}"; do
            printf '  [%s]=%s\n' "$(_nds_cfg_shell_quote "$url")" \
                "$(_nds_cfg_shell_quote "${NDS_GIT_KEY_KIND[$url]}")"
        done
        echo ")"
        echo ""
    fi
}

# Description: Dump all scoped + git arrays to a file for sudo re-exec (AAs cannot cross sudo).
# Arguments:
# - path: <String> Destination file
nds_cfg_dump_scoped_file() {
    local path="$1"
    {
        echo "# NDS scoped config — sourced after elevate / via NDS_SCOPED_CONFIG_FILE"
        nds_cfg_sync_store_to_scoped
        local scope
        for scope in FLAKE DISK BOOT ENCRYPTION NETWORK PLATFORM ACCESS REGION SECURITY QUICK; do
            nds_cfg_export_scoped_block "$scope"
            echo ""
        done
        nds_cfg_export_git_maps
    } >"$path"
}

# Description: Source NDS_SCOPED_CONFIG_FILE if set, then merge scoped arrays into CONFIG_DATA.
nds_cfg_load_scoped_file() {
    local path="${NDS_SCOPED_CONFIG_FILE:-}"
    [[ -n "$path" && -f "$path" ]] || return 0
    # shellcheck disable=SC1090
    source "$path"
    nds_cfg_sync_scoped_to_store
}

# Description: Apply scoped array env mirrors that may exist in the current shell
# (user sourced declare -A before starting NDS in the same process — rare).
nds_cfg_apply_scoped_arrays() {
    nds_cfg_load_scoped_file
    nds_cfg_sync_scoped_to_store
}
