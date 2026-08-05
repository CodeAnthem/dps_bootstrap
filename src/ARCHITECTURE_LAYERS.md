# NDS layer rules (logic / ui / tests)

## Layout

```text
src/<feature>/
  load.sh          # entry; sources logic/ + ui/
  logic/           # no TTY; no nds_cfg_get/set
  ui/              # prompts + display; no store writes
  tests/           # *_test.sh / *_prompts_test.sh
```

## Filenames

`<area>[_<sub>]_<type>.sh` — types: `logic` | `prompts` | `display` | `flow` | `prompts_test` | `test`  
Lowercase; no spaces or special characters.

## Config AA

- Main/action own the store; pass full config AA into feature entry; feature returns AA updates.
- Logic: prefer nameref AA; prompts may use `nds_cfg_get`/`set` only under `nds_cfg_aa_bind` (redirect onto feature AA — no `CONFIG_DATA` writes).
- Helpers: `nds_cfg_aa_from_store`, `nds_cfg_aa_to_store`, `nds_cfg_aa_bind`/`unbind`, `nds_feature_require_keys`, `nds_aa_get`/`set`.

## Mode

- `NDS_MODE=interactive|unattended` (`nds_mode_resolve`).
- Action selection: valid `NDS_ACTION` proceeds; unattended + missing/invalid action → fail.
- Preview: skip when unattended or preview-skip flag.
- Features decide their own UI (e.g. git GH device) from their config; no global phase-type registry.

## Install / settings notes

- `install/logic/` — flake gate + ctx AA helpers (no TTY).
- `install/ui/` — flake gate / host prompts (write via bound `nds_cfg_*`).
- Feature UI may call `nds_cfg_get`/`set` only while `nds_cfg_aa_bind` redirects them onto the feature AA; orchestrators merge AA → store.
- Confirm menus stay under `app/menus`.
- `settings/state/` — store + AA bridge (logic)
- `settings/ui/` — menus / ask_*
- `settings/presets/` — hook registration + injection
