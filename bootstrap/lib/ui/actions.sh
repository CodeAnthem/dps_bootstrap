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

# Description: Show grouped install preview (called from action_preview in each action).
# Arguments:
# - title:     <String> Action headline
# - configure: <String> One-line summary of what the user configures
# - steps:     <String> One-line summary of what NDS does after confirm
nds_action_preview() {
    local title="$1"
    local configure="$2"
    local steps="$3"

    nds_ui_h "$title"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "$configure"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "$steps"
    nds_ui_b ""
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
    nds_ui_i "Prompt to back up encryption keys before reboot"
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
