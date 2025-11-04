#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Progress Wrapper
# Description: Run commands with spinner, timestamps, and success/failure output.
# ==================================================================================================

# Usage: run_step "Description" command [args...]
# Example: run_step "Formatting root partition" mkfs.ext4 /dev/sda1
run_step() {
    local description="$1"
    shift
    local start_time end_time duration
    local tmp_output
    tmp_output=$(mktemp)

    # Timestamp
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Start spinner in background
    printf " %s ⏳ [INFO] - %s " "$timestamp" "$description" >&2
    {
        local spinstr='|/-\'
        local delay=0.1
        while :; do
            for c in $spinstr; do
                printf "\b%c" "$c" >&2
                sleep $delay
            done
        done
    } &
    local spinner_pid=$!

    # Run command and capture output
    start_time=$(date +%s%3N)
    "$@" >"$tmp_output" 2>&1
    local rc=$?
    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))
    duration_fmt=$(awk "BEGIN { printf \"%.2f\", $duration / 1000 }")

    # Stop spinner
    kill "$spinner_pid" >/dev/null 2>&1
    wait "$spinner_pid" 2>/dev/null

    # Clear spinner line
    printf "\r\033[K" >&2

    # Print result
    if [[ $rc -eq 0 ]]; then
        printf " %s ✅ [PASS] - %s (in %ss)\n" "$timestamp" "$description" "$duration_fmt" >&2
    else
        printf " %s ❌ [FAIL] - %s (in %ss) [Error: %d]\n" "$timestamp" "$description" "$duration_fmt" "$rc" >&2
        printf " ───────────────────────────────────────────────────────────────\n" >&2
        sed 's/^/  /' "$tmp_output" >&2
        printf " ───────────────────────────────────────────────────────────────\n" >&2
    fi

    rm -f "$tmp_output"
    return $rc
}
