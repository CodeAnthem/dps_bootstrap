# NDS actions

Each subdirectory is one operator-facing flow (`setup.sh`).

## Required functions

| Function | Purpose |
|----------|---------|
| `action_presets` | Print preset ids (one per line) for this action |
| `action_preview` | Describe what will happen (no mutations) |
| `action_setup` | Run install / remote flow |

## Optional hooks

| Function | Purpose |
|----------|---------|
| `action_extend_settings_manager` | After action import, before settings init + heavy modules |
| `action_config` | Tweak preset priority/display after bundle enable |
| `action_presets_paths` | Extra preset dirs/files (one path per line) |
| `action_presets_extend` | Custom load/inject after builtins |
| `action_on_accept` | After preview confirm, before `action_setup` |

## Lifecycle

1. Preload basic runtime (core, settings-manager, system-vars, UI, actions)
2. Discover / select action
3. Import action `setup.sh`
4. Optional `action_extend_settings_manager`
5. Catalog presets (no enable yet)
6. Load remaining framework (git, install, flake, nixcfg)
7. Enable action preset bundle → seed defaults
8. Configure → preview → confirm → `action_setup`

## Flake naming

- `nds_flake_prepare`, `nds_flake_detect_disko`, … — `src/features/flake/helpers.sh`
- `nds_flake_install_prepare_and_verify`, `nds_flake_install_confirm` — `src/features/install/flake-pipeline.sh`
