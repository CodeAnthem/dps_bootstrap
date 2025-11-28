#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-06
# Description:   Argument parsing helpers for entry scripts
# Feature:       Flag presence, key-value extraction, short and long option support
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Globals
# --------------------------------------------------------------------------------------------------
declare -gA NDS_ARGS=()          # Stores parsed key-value pairs
declare -ga NDS_POSITIONAL_ARGS=()  # Stores non-option positional args

# --------------------------------------------------------------------------------------------------
# Public: Parse all script arguments into NDS_ARGS and NDS_POSITIONAL_ARGS
# Usage: nds_arg_parse "$@"
# --------------------------------------------------------------------------------------------------
nds_arg_parse() {
    local key value next isValuePending="false"
    NDS_ARGS=()
    NDS_POSITIONAL_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --) # end of options
                shift
                NDS_POSITIONAL_ARGS+=("$@")
                break
                ;;
            --*=*) # --key=value
                key="${1%%=*}"
                value="${1#*=}"
                NDS_ARGS["$key"]="$value"
                ;;
            --*) # --key value or just --flag
                key="$1"
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    NDS_ARGS["$key"]="$2"
                    shift
                else
                    NDS_ARGS["$key"]="true"
                fi
                ;;
            -[a-zA-Z0-9]?=*) # short flag with = (e.g., -f=value)
                key="${1%%=*}"
                value="${1#*=}"
                NDS_ARGS["$key"]="$value"
                ;;
            -[a-zA-Z0-9]*) # multiple short flags (-abc -> -a, -b, -c)
                local shortFlags="${1#-}"
                local i flag
                for ((i=0; i<${#shortFlags}; i++)); do
                    flag="-${shortFlags:i:1}"
                    # If last flag has a value (e.g., -a value)
                    if (( i == ${#shortFlags}-1 )) && [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                        NDS_ARGS["$flag"]="$2"
                        shift
                    else
                        NDS_ARGS["$flag"]="true"
                    fi
                done
                ;;
            *) # positional argument
                NDS_POSITIONAL_ARGS+=("$1")
                ;;
        esac
        shift
    done
}

# --------------------------------------------------------------------------------------------------
# Public: Check if a flag/option exists
# Usage: nds_arg_has <flag>
# --------------------------------------------------------------------------------------------------
nds_arg_has() {
    local flag="$1"
    [[ -n "${NDS_ARGS[$flag]:-}" ]]
}

# --------------------------------------------------------------------------------------------------
# Public: Get value for a flag or key (returns empty string if not found)
# Usage: nds_arg_value <flag>
# --------------------------------------------------------------------------------------------------
nds_arg_value() {
    local flag="$1"
    echo "${NDS_ARGS[$flag]:-}"
}
