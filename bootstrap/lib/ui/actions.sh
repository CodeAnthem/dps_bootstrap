#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Action overview screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2026-06-29
# Description:   Install preview and pre-install confirmation screens
# ==================================================================================================

nds_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Description: Print comma-separated items as indented lines (optional helper).
# Actions own section titles and layout; call this only for simple bullet lists.
nds_action_items() {
    local items="$1"
    local item
    IFS=',' read -ra _items <<< "$items"
    for item in "${_items[@]}"; do
        nds_ui_i "$(nds_trim "$item")"
    done
}

# Description: Destructive install warning before partitioning.
# Arguments:
# - disk:     <String> Target block device
# - strategy: <String> nds | disko | flake
# - extra:    <String> Optional extra note
nds_ui_install_warning() {
    local disk="$1"
    local strategy="${2:-nds}"
    local extra="${3:-}"

    new_section
    section_header "Ready to install"

    if [[ "$NDS_UI_COLOR" == true ]]; then
        nds_ui_b "$(printf '\033[31;1mAll data on %s will be permanently erased.\033[0m' "$disk")"
    else
        nds_ui_b "All data on ${disk} will be permanently erased."
    fi

    nds_ui_b ""
    case "$strategy" in
        flake)
            nds_ui_b "Disk strategy is flake — NDS will not partition; /mnt must already be mounted."
            ;;
        disko)
            nds_ui_b "Disko will repartition ${disk}."
            ;;
        *)
            nds_ui_b "NDS will repartition and format ${disk}."
            ;;
    esac

    nds_ui_b ""
    nds_ui_b "Estimated time: 10–30 minutes (disk speed and download size vary)."
    nds_ui_b ""
    nds_ui_b "What happens next:"
    nds_ui_i "Partition and mount the target disk"
    nds_ui_i "Generate hardware-configuration.nix on the live system"
    nds_ui_i "Run nixos-install (Nix will download packages)"
    nds_ui_i "Prompt to back up encryption keys after installation (before you reboot manually)"
    [[ -n "$extra" ]] && nds_ui_b "" && nds_ui_b "$extra"
    nds_ui_b ""
}

# Description: Show install warning and ask for final confirmation.
nds_action_confirm_install() {
    local disk="$1"
    local strategy="${2:-nds}"
    local extra="${3:-}"

    nds_ui_install_warning "$disk" "$strategy" "$extra"
    nds_askUserToProceed "Start installation now" || return 1
    return 0
}
