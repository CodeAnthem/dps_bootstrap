#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Choice and option validation functions
# ==================================================================================================

# =============================================================================
# CHOICE VALIDATION FUNCTIONS
# =============================================================================

# Validate choice from options (pipe-separated)
# Usage: validate_choice "dhcp" "dhcp|static"
validate_choice() {
    local value="$1"
    local options="$2"
    
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        if [[ "$value" == "$choice" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate node role (convenience wrapper for validate_choice)
# Usage: validate_role "worker"
validate_role() {
    validate_choice "$1" "worker|gateway|gpu-worker"
}
