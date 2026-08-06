# NDS `src` layout

Entry: `app/main.sh`. Shared UI: `ui/`. Settings: `settingsManager/`. Target helpers: `scripts/`. Capability libs: `tools/`.

## Top-level

| Path | Purpose |
|------|---------|
| `app/` | Backbone — entry, lifecycle, action runtime, confirm menus, VERSION |
| `core/` | Small shared primitives (import, mode/skip, runtime, platform, strings) |
| `ui/` | Shared terminal UI only |
| `settingsManager/` | Config store, preset **data**, SM **logic/ui**, validators |
| `tools/` | Sourcable capabilities (`nds_pkg_*`, `nds_qr_*`, `nds_gh_*`, …) — no domain policy |
| `scripts/` | Scripts copied onto the installed machine (`nds-switch`, `nds-git-ssh`, `nds-clean`) |
| `git/` | SSH keys, probe/clone, wizard UI; calls `nds_gh_*` / `nds_qr_*` |
| `install/` | Install pipelines (logic/ui); remote unlock stays install-domain |
| `bundle/` | Install backup archive; features contribute via `nds_bundle_register_*` |
| `actions/` | Per-action `setup` / run modules |
| `tests/` | Cross-feature / integration suites only |

Feature folders use `logic/` + `ui/` (+ colocated `tests/` when present). Pure **data** lives under `data/` and is not auto-sourced.

## UI package

| File | Owns |
|------|------|
| `terminal.sh` | Terminal capability, indentation, layout rows |
| `logger.sh` | Single leveled logger (`nds_log` + `info`/`warn`/…) |
| `section.sh` | Banner + section screens |
| `prompts.sh` | Yes/no and numbered-menu input |
| `stepAnimation.sh` | Step spinner / `nds_step_*` |

Skip / auto-confirm registry lives in **core mode**, not UI.

## settingsManager

```
settingsManager/
  data/builtin/     # preset files (loaded on demand)
  logic/
    state/          # CONFIG_DATA store, AA bridge
    presets/        # catalog / enable / inject
    validators/     # validate_<type>_<action>
    reference/      # country defaults, etc.
  ui/               # ask_* menus
```

Validators are owned by settingsManager. Public names: `validate_git_url`, `validate_ip`, `validate_toggle_normalize`, …

## Loading

`nds_import_tree` recursively sources `.sh` under a feature root.

- Order: `lib` → `logic` → `state` → `ui`, then other dirs alphabetically; files alphabetically within each dir
- Skips: `tests/`, `data/`, `fixtures/`, `specs/`, `load.sh`, `_`-prefixed names

Backbone stages: `nds_lifecycle_load_core` → `…_ui` → `…_actions`; settingsManager and heavy features load on action runtime.

## Capability vs domain

- `tools/` ensures binaries (may animate + log on first nix warm) and exposes APIs
- Features decide *when* to call them (git UI shows QR; SM does not own `gh`)

## Docs rule

This file is the single structural overview for `src/`. Prefer updating it when layout changes.
