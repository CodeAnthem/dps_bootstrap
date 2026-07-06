#!/usr/bin/env bash
# ==================================================================================================
# NDS - Menu: local install confirmation screen
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

nds_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

nds_action_items() {
    local items="$1"
    local item
    IFS=',' read -ra _items <<< "$items"
    for item in "${_items[@]}"; do
        nds_ui_i "$(nds_trim "$item")"
    done
}

nds_ui_install_warning() {
    local disk="$1"
    local strategy="${2:-nds}"
    local extra="${3:-}"
    local strategy_label

    strategy_label=$(nds_disk_strategy_label "$strategy")

    section_header "Ready to install"
    nds_ui_b "Review the summary below. Installation does not start until you confirm at the end."
    nds_ui_b ""

    nds_ui_h "Target disk"
    if [[ "$NDS_UI_COLOR" == true ]]; then
        nds_ui_i "$(printf '%s\033[31;1m — all data will be permanently erased\033[0m' "$disk")"
    else
        nds_ui_i "${disk} — all data will be permanently erased"
    fi
    nds_ui_b ""

    nds_ui_h "Partitioning"
    nds_ui_i "$strategy_label"
    nds_ui_b ""

    nds_ui_h "Steps"
    case "$strategy" in
        flake)
            nds_ui_i "1. Verify /mnt is already mounted (NDS does not partition)"
            nds_ui_i "2. Generate facter.json on the live system (nixos-facter)"
            nds_ui_i "3. Run nixos-install from your flake (Nix downloads and builds packages)"
            nds_ui_i "4. Offer an install backup zip (config and logs)"
            ;;
        *)
            nds_ui_i "1. Partition and format ${disk} (LUKS2 if encryption is enabled)"
            nds_ui_i "2. Generate facter.json on the live system (nixos-facter)"
            nds_ui_i "3. Run nixos-install — Nix downloads and builds packages"
            nds_ui_i "4. Offer an install backup zip (config, logs, and encryption keys if encrypted)"
            ;;
    esac
    nds_ui_b ""

    [[ -n "$extra" ]] && nds_ui_b "$extra" && nds_ui_b ""
}

nds_action_confirm_install() {
    local disk="$1"
    local strategy="${2:-nds}"
    local extra="${3:-}"

    nds_ui_install_warning "$disk" "$strategy" "$extra"
    nds_askUserToProceed "Start installation now" || return 1
    return 0
}
