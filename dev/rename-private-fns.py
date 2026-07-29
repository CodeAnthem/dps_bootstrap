#!/usr/bin/env python3
"""Apply _featurename_* private function renames across NDS shell scripts."""

from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Order matters: longer / more specific replacements first.
RENAMES: list[tuple[str, str]] = [
    ("_nixinstall_", "_install_"),
    ("_validate_action", "_app_validate_action"),
    ("_elevate_to_root", "_app_elevate_to_root"),
    ("_callHook", "_app_call_hook"),
    ("_main_stopHandler", "_app_stop_handler"),
    ("_action_configure_presets", "_app_action_configure_presets"),
    ("_import_and_validate_file", "_core_import_and_validate_file"),
    ("_import_showErrors", "_core_import_show_errors"),
    ("_cfg_prompt_value", "_settings_prompt_value"),
    ("_export_is_always", "_settings_export_is_always"),
    ("_export_is_when_set", "_settings_export_is_when_set"),
    ("_export_is_hardware", "_settings_export_is_hardware"),
    ("_export_is_skipped", "_settings_export_is_skipped"),
    ("_export_should_include", "_settings_export_should_include"),
    ("_configurator_sort_presets", "_settings_configurator_sort_presets"),
    ("_deploy_slug_part", "_git_deploy_slug_part"),
    ("_slug_part", "_git_slug_part"),
    ("_templates_dir", "_flake_templates_dir"),
    ("_discover_roles", "_flake_discover_roles"),
    ("_disk_by_id", "_flake_disk_by_id"),
    ("_scaffold_host_folder", "_flake_scaffold_host_folder"),
    ("_nix_target_root_mounted", "_install_nix_target_root_mounted"),
    ("_nix_target_root", "_install_nix_target_root"),
    ("_nix_store_free_mb", "_install_nix_store_free_mb"),
    ("_nix_scratch_store_path", "_install_nix_scratch_store_path"),
    ("_nix_install_store_uri", "_install_nix_install_store_uri"),
    ("_nix_install_store_args", "_install_nix_install_store_args"),
    ("_nix_ensure_store_ready", "_install_nix_ensure_store_ready"),
    ("_nix_combined_nix_config", "_install_nix_combined_nix_config"),
    ("_nix_nixos_install_config", "_install_nix_nixos_install_config"),
    ("_nix_canonical_store_path", "_install_nix_canonical_store_path"),
    ("_nix_system_profile_ok", "_install_nix_system_profile_ok"),
    ("_nix_link_system_profile", "_install_nix_link_system_profile"),
    ("_nix_install_bootloader", "_install_nix_install_bootloader"),
    ("_nix_find_system_closure", "_install_nix_find_system_closure"),
    ("_nix_ensure_system_profile", "_install_nix_ensure_system_profile"),
    ("_nix_ensure_current_system_link", "_install_nix_ensure_current_system_link"),
    ("_nix_reinstall_bootloader", "_install_nix_reinstall_bootloader"),
    ("_nix_remount_target_if_needed", "_install_nix_remount_target_if_needed"),
    ("_nix_flake_system_ref", "_install_nix_flake_system_ref"),
    ("_partition_partitions_have_filesystems", "_install_partition_partitions_have_filesystems"),
    ("_partition_disk_has_partitions", "_install_partition_disk_has_partitions"),
    ("_partition_disk_has_label", "_install_partition_disk_has_label"),
    ("_partition_has_known_signatures", "_install_partition_has_known_signatures"),
    ("_partition_summarize_disk", "_install_partition_summarize_disk"),
    ("_partition_check_disk_state", "_install_partition_check_disk_state"),
    ("_partition_disko_generate_params", "_install_partition_disko_generate_params"),
    ("_partition_disko_pick_template", "_install_partition_disko_pick_template"),
    ("_partition_disko_apply", "_install_partition_disko_apply"),
    ("_partition_in_use", "_install_partition_in_use"),
    ("_blkid_uuid", "_install_blkid_uuid"),
    ("_findmnt_source", "_install_findmnt_source"),
    ("_urandom_chars", "_install_urandom_chars"),
    ("_run_age_keygen", "_sops_run_age_keygen"),
    ("_enroll_sops_key", "_sops_enroll_key"),
    ("_ui_colored", "_bundle_ui_colored"),
    ("_install_install_", "_install_"),
]


def transform(text: str) -> str:
    for old, new in RENAMES:
        text = text.replace(old, new)
    return text


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.sh")):
        if ".git" in path.parts:
            continue
        original = path.read_text(encoding="utf-8")
        updated = transform(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
    print(f"updated {changed} shell files")


if __name__ == "__main__":
    main()
