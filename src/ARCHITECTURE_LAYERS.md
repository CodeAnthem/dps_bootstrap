# NDS layer rules (logic / ui / tests)

## Layout

```text
src/<feature>/
  load.sh          # entry; sources logic/ + ui/
  logic/           # no TTY; nameref AA only (no bare store I/O)
  ui/              # prompts + display; nds_aa_ask_* / nds_feat_cfg_* under bind
  tests/           # *_test.sh / *_prompts_test.sh
```

## Filenames

`<area>[_<sub>]_<type>.sh` — types: `logic` | `prompts` | `display` | `flow` | `prompts_test` | `test`  
Lowercase; no spaces or special characters. Type is in the filename — no `ui/prompts/` subfolders.

## Shared tools (`src/tools/`)

| Path | Role |
|------|------|
| `tools/*.sh` | Target CLIs copied onto the installed machine |
| `tools/lib/` | Sourcable capability helpers for any feature/action |

`tools/lib` helpers: detect/ensure binary (PATH or nixpkgs#), run one job, **no domain policy** (no keys/secrets/git decisions). Ensure paths may show **step animation + logs on first nix install**; print/run helpers stay silent.

Examples: `nds_pkg_*`, `nds_qr_*`, `nds_gh_*` (ensure + session + API), `nds_age_keygen`, `nds_facter_write`.

**GH vs git:** all `gh` CLI capability lives in `tools/lib` (`gh.sh`, `gh_session.sh`, `gh_api.sh`). Git only orchestrates (key paths, titles, collision prompts in `git/logic/gh_orch_logic.sh` + wizard UI). Callers decide when to register/show QR.

**QR:** `nds_qr_print` / `nds_qr_ensure` in tools/lib — git UI labels and chooses when to display.

## Bundle (core feature)

`src/bundle/` — install backup zip/tar. Features add payload via `nds_bundle_register_{file,dir,text,hook}`; `nds_bundle_create` runs hooks then packs. Compat aliases: `nds_install_bundle_*`.

## Config AA

- Main/action own the store; pass full config AA into feature entry; feature returns AA updates.
- Feature UI: `nds_aa_ask_*` + `nds_feat_cfg_*` under `nds_cfg_aa_bind` (never bare `nds_cfg_ask_*`).
- Settings presets/menus: `nds_cfg_ask_*` against `CONFIG_DATA`.
- Orchestrator: `nds_action_call_feature` → store↔AA around `fn(mode, cfg)`.

## Mode

- `NDS_MODE=interactive|unattended` (`nds_mode_resolve`).
- Action selection: valid `NDS_ACTION` proceeds; unattended + missing/invalid action → fail.
- Preview: skip when unattended or preview-skip flag.
- Features decide their own UI from their config; no global phase-type registry.

## Install / settings

- `install/logic/` — install pipelines, encryption, remote unlock, diagnostics (no TTY preferred).
- `install/ui/` — flake gate / host / scaffold / encryption prompts + gate flow.
- Confirm menus stay under `app/menus`.
- `settings/state/` — store + AA bridge.
- `settings/ui/` — menus / ask_* / aa-ask.
- `settings/presets/` — hook registration + injection.
