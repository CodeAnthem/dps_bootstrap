#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Question
# Feature:       Boolean question (yes/no) for confirmations
# ==================================================================================================

_question_promptHint() {
    echo "(yes/no)"
}

_question_validate() {
    local value="$1"
    [[ "${value,,}" =~ ^(yes|no|y|n)$ ]]
}

_question_normalize() {
    local value="$1"
    case "${value,,}" in
        yes|y) echo "yes" ;;
        no|n) echo "no" ;;
    esac
}

_question_errorCode() {
    echo "Enter yes or no"
}

# Auto-register this settingType
nds_cfg_settingType_register "question"
