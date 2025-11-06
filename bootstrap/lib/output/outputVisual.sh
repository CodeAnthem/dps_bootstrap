#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-22 | Modified: 2025-11-06
# Description:   Visual formatting helpers (titles, section headers, screen clear)
# Feature:       draw_title, section_header, section_title, new_section
# ==================================================================================================

# ------------------------------------------------------------------------------
# Draw a box with a centered title
# Usage: nds_draw_title "Title text" [length]
# ------------------------------------------------------------------------------
nds_draw_title() {
    local title="$1"
    local length="${2:-100}"
    local innerLength=$((length - 2))
    local border

    border=$(printf '─%.0s' $(seq 1 "$innerLength"))
    printf "╭%s╮\n" "$border" >&2
    printf "│%-*s│\n" "$innerLength" "$title" >&2
    printf "╰%s╯\n" "$border" >&2
}

# ------------------------------------------------------------------------------
# Section header (smaller box)
# Usage: nds_section_header "Header title"
# ------------------------------------------------------------------------------
nds_section_header() {
    nds_new_section
    nds_draw_title "  $1" 50
}

# ------------------------------------------------------------------------------
# Section title (large box)
# Usage: nds_section_title "Main section"
# ------------------------------------------------------------------------------
nds_section_title() {
    nds_new_section
    nds_draw_title " === $1 === " 100
}

# ------------------------------------------------------------------------------
# Clear screen but keep scrollback history
# ------------------------------------------------------------------------------
nds_new_section() {
    printf "\033[2J\033[H" >&2
}
