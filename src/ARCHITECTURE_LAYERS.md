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
- Logic and prompts: no `nds_cfg_get` / `nds_cfg_set`.
- Helpers: `nds_cfg_aa_from_store`, `nds_cfg_aa_to_store`, `nds_feature_require_keys`, `nds_aa_get` / `nds_aa_set`.

## Mode

- `NDS_MODE=interactive|unattended` (`nds_mode_resolve`).
- Action selection: valid `NDS_ACTION` proceeds; unattended + missing/invalid action → fail.
- Preview: skip when unattended or preview-skip flag.
- Features decide their own UI (e.g. git GH device) from their config; no global phase-type registry.

## Settings layout

- `settings/state/` — store + AA bridge (logic)
- `settings/ui/` — menus / ask_*
- `settings/presets/` — hook registration + injection
