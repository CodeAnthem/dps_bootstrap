#!/usr/bin/env bash
# ==================================================================================================
# NDS - App-owned runtime state
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-07-29
# Description:   Explicit globals owned by the app layer (actions + session)
# ==================================================================================================

declare -ga NDS_ACTION_NAMES=()
declare -gA NDS_ACTION_DATA=()
declare -g NDS_ACTIONS_DIR=""
declare -g NDS_CURRENT_ACTION=""
