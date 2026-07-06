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
| `action_config` | Tweak preset priority/display after bundle enable |
| `action_presets_paths` | Extra preset dirs/files (one path per line) |
| `action_presets_extend` | Custom load/inject after builtins |
| `action_on_accept` | After preview confirm, before `action_setup` |

## Lifecycle

`nds_actions_main` → discover → select → `action_presets` bundle → seed → menu/configure → preview → confirm → `action_setup`.

## Flake naming

- `nds_flake_prepare`, `nds_flake_detect_disko`, … — `tools/flake/helpers.sh`
- `nds_flake_install_prepare_and_verify`, `nds_flake_install_confirm` — `core/install/flake-pipeline.sh`
