# NDS `src` layout

Entry: `app/main.sh`. Shared UI: `ui/`. Settings: `settingsManager/`. Target helpers: `scripts/`. Capability libs: `tools/`.

## Top-level

| Path | Purpose |
|------|---------|
| `app/` | Backbone — entry, core, lifecycle, runtime, menus, VERSION |
| `ui/` | Shared terminal UI only |
| `settingsManager/` | Config store, preset **data**, SM **logic/ui**, validators |
| `tools/` | Sourcable capabilities (`nds_pkg_*`, `nds_qr_*`, `nds_gh_*`, …) |
| `scripts/` | Scripts copied onto the installed machine |
| `git/` | SSH keys, probe/clone, wizard UI; calls `nds_gh_*` / `nds_qr_*` |
| `install/` | Install pipelines (`logic/` + `ui/`); remote unlock stays install-domain |
| `bundle/` | Install backup archive; contrib via `nds_bundle_register_*` |
| `actions/` | Per-action `setup.sh` + `logic/` + `ui/` |
| `tests/` | Cross-feature runner + framework only — suites live under features |

Feature folders use `logic/` + `ui/` (+ colocated `tests/`). Pure **data** under `data/` is not auto-sourced.

## Backbone (`app/`)

```
app/
  main.sh                 # entry
  VERSION
  core/                   # import, mode/skip, runtime, platform, strings
  lifecycle/              # staged loaders
  runtime/                # bootstrap, actions, cli, exit, state
  menus/                  # install/remote confirm
  tests/                  # mode / skip / standalone suites
```

## UI package

| File | Owns |
|------|------|
| `terminal.sh` | Capability, indentation, layout |
| `logger.sh` | Single leveled logger |
| `section.sh` | Banner + section screens |
| `prompts.sh` | Yes/no + numbered menu input |
| `stepAnimation.sh` | Step spinner |

## settingsManager

```
settingsManager/
  data/builtin/
  logic/{state,presets,validators,reference}/
  ui/
  tests/
```

Validators: `validate_<type>_<action>` (e.g. `validate_git_url`).

## Loading

`nds_import_tree` — order `lib` → `logic` → `state` → `ui`, then other dirs; skips `tests/`, `data/`, `load.sh`, `_`*.

## Capability vs domain

`tools/` = ensure/APIs. Features decide when to call them.

## Docs rule

This file is the single structural overview for `src/`.
