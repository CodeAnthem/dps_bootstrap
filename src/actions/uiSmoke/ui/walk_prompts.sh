#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI smoke walk (interactive, human-driven)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-07
# Description:   Cycle shared + SM + confirm prompts. No wipe / install / network APIs.
# ==================================================================================================

_nds_uismoke_pause() {
    local title="$1"
    nds_ui_section_header "$title"
    nds_ui_b "Follow the prompts. Escapes: n / b where offered (walk continues)."
    nds_ui_b ""
}

_nds_uismoke_step_ok() {
    local label="$1"
    info "uiSmoke: ok — ${label}"
}

# Description: Interactive walk of every core prompt surface (human verifies wiring).
nds_uismoke_walk() {
    local tmp_label prompt choice

    # ----- shared ui/prompts -----
    _nds_uismoke_pause "1/7 — shared prompts (yes / no / back)"
    nds_ask_user_continue "Smoke: continue (try y, then re-run step mentally for b/n)" || true
    _nds_uismoke_step_ok "nds_ask_user_continue"
    nds_ask_user_to_proceed "Smoke: proceed?" || true
    _nds_uismoke_step_ok "nds_ask_user_to_proceed"

    _nds_uismoke_pause "2/7 — numbered menu digit"
    nds_ui_b "Demo choices:"
    nds_ui_choice_row "1" "alpha" "first option"
    nds_ui_choice_row "2" "beta" "second option"
    nds_ui_b ""
    prompt="$(nds_ui_numbered_prompt 1 2 "" "Pick a demo option" true)"
    if choice=$(nds_ui_read_menu_digit "$prompt" 1 2 true); then
        nds_ui_b "You chose: ${choice}"
    fi
    _nds_uismoke_step_ok "nds_ui_numbered_prompt + nds_ui_read_menu_digit"

    # ----- settingsManager field asks -----
    _nds_uismoke_pause "3/7 — settingsManager field prompts"
    nds_cfg_set UISMOKE_TOGGLE "false"
    nds_cfg_ask_toggle UISMOKE_TOGGLE "Smoke toggle" false
    nds_cfg_ask_string UISMOKE_STRING "Smoke string" "hello" false
    nds_cfg_ask_int UISMOKE_INT "Smoke int" "42" 1 100
    nds_cfg_ask_choice UISMOKE_CHOICE "Smoke choice" "a|b|c" "a=Alpha|b=Beta|c=Charlie" "a"
    nds_cfg_ask_numbered_choice UISMOKE_NCHOICE "a|b|c" "a=Alpha|b=Beta|c=Charlie" "a"
    nds_cfg_ask_ip UISMOKE_IP "Smoke IP" "192.168.1.10" false
    nds_cfg_ask_hostname UISMOKE_HOST "Smoke hostname" "smokehost" false
    nds_cfg_ask_username UISMOKE_USER "Smoke username" "smokeuser" false
    nds_cfg_ask_port UISMOKE_PORT "Smoke port" "22"
    nds_cfg_ask_path UISMOKE_PATH "Smoke path" "/tmp" false
    nds_cfg_ask_url UISMOKE_URL "Smoke URL" "git@github.com:example/repo.git" false
    nds_cfg_ask_mask UISMOKE_MASK "Smoke mask" "24"
    nds_cfg_ask_locale UISMOKE_LOCALE "Smoke locale"
    nds_cfg_set UISMOKE_LOCALE "$(nds_cfg_get UISMOKE_LOCALE)"
    [[ -n "$(nds_cfg_get UISMOKE_LOCALE)" ]] || nds_cfg_set UISMOKE_LOCALE "en_US.UTF-8"
    nds_cfg_ask_keyboard UISMOKE_KB "Smoke keyboard"
    [[ -n "$(nds_cfg_get UISMOKE_KB)" ]] || nds_cfg_set UISMOKE_KB "us"
    nds_cfg_ask_country UISMOKE_CC "Smoke country"
    # timezone / disk / secret are optional heavier — still walk them
    nds_cfg_ask_timezone UISMOKE_TZ "Smoke timezone" || true
    nds_cfg_ask_disk UISMOKE_DISK "Smoke disk (list only — pick any; unused)" || true
    nds_cfg_ask_secret UISMOKE_SECRET "Smoke secret (min 8)" 8 false || true
    _nds_uismoke_step_ok "nds_cfg_ask_* field set"

    # ----- export / summary display -----
    _nds_uismoke_pause "4/7 — settings export screen"
    nds_cfg_print_backup
    nds_cfg_confirm_saved || true
    _nds_uismoke_step_ok "nds_cfg_print_backup + confirm"

    # ----- app confirms (fake targets — no wipe) -----
    _nds_uismoke_pause "5/7 — install / remote confirm screens (fake)"
    export NDS_FLAKE_HOST="smoke-host"
    export NDS_FLAKE_INSTALL_PATH="/mnt/etc/nixos"
    export NDS_FLAKE_SOURCE="remote"
    export NDS_INSTALL_MODE="local"
    nds_ui_install_warning "/dev/null" "nds" "(uiSmoke — fake disk, will not format)"
    nds_ask_user_to_proceed "Smoke: pretend Start installation now" || true
    nds_action_confirm_remote_install "127.0.0.1" "(uiSmoke — no remote install)" || true
    _nds_uismoke_step_ok "install + remote confirm UIs"

    # ----- install confirms -----
    _nds_uismoke_pause "6/7 — overwrite / preflight / format confirms"
    nds_install_ui_section_flake_access
    nds_install_ui_section_nixos_install
    nds_install_ui_confirm_hardware_overwrite "facter.json" || true
    nds_install_ui_confirm_scaffold_overwrite "/tmp/nds-uismoke-host" || true
    nds_install_ui_preflight_continue || true
    nds_install_ui_confirm_disk_format "/dev/null" "has_fs" || true
    nds_install_logs_fetch_hints || true
    _nds_uismoke_step_ok "install UI confirms"

    # ----- git UI pieces that need no API -----
    _nds_uismoke_pause "7/7 — git collision + hints (no gh network)"
    nds_git_ui_ask_gh_title_collision \
        "Smoke: pretend deploy key title collision on owner/repo." || true
    nds_git_ui_deploy_key_hint "CodeAnthem" "dps_swarm"
    nds_git_ui_offer_clear_gh_session || true
    nds_app_ui_show_failure 42 || true
    _nds_uismoke_step_ok "git collision / hints / failure display"

    nds_ui_section_header "UI smoke complete"
    nds_ui_b "All prompt surfaces in this walk were exercised."
    nds_ui_b "Git wizard full flows (gh login / key register) stay on real installFlake."
    nds_ui_b ""
    return 0
}
