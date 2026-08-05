#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle registry unit checks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

nds_test_bundle_register_api() {
    nds_bundle_reset
    nds_bundle_register_hook nds_bundle_contrib_core

    local tmp staging
    tmp=$(mktemp)
    printf 'secret-body' >"$tmp"
    nds_bundle_register_file "secrets/extra.txt" "$tmp"
    nds_bundle_register_text "hello.txt" "world"

    _test_contrib_extra() {
        nds_bundle_register_text "from-hook.txt" "hooked"
    }
    nds_bundle_register_hook _test_contrib_extra

    nds_bundle_reset_contribs
    nds_bundle_run_hooks
    nds_bundle_register_file "secrets/extra.txt" "$tmp"
    nds_bundle_register_text "hello.txt" "world"

    staging=$(mktemp -d)
    nds_bundle_apply_contribs "$staging" || {
        rm -f "$tmp"
        rm -rf "$staging"
        return 1
    }

    [[ -f "${staging}/hello.txt" ]] || return 1
    [[ "$(<"${staging}/hello.txt")" == "world" ]] || return 1
    [[ -f "${staging}/from-hook.txt" ]] || return 1
    [[ -f "${staging}/secrets/extra.txt" ]] || return 1

    rm -f "$tmp"
    rm -rf "$staging"
    nds_bundle_reset
    nds_bundle_register_hook nds_bundle_contrib_core
    return 0
}
