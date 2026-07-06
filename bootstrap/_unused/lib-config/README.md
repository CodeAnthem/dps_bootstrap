# config

Interactive configuration: scripted presets, shared prompts/validators, menu, and `NDS_*` env export.

## Layout

| Path | Role |
|------|------|
| `store.sh` | `CONFIG_DATA`, preset registry, get/set, env export |
| `validate.sh` | Field validators (`validate_*`) |
| `ask.sh` | Prompt helpers (`nds_cfg_ask_*`) |
| `country.sh` | Country → timezone/locale defaults |
| `registry.sh` | Preset load, defaults seed, validate/configure dispatch |
| `menu.sh` | Category menu (no hook replay loop) |
| `presets/` | One file per domain: defaults, configure, summary, validate |

## Preset contract

Each preset in `presets/*.sh` defines:

- `${name}_defaults` — seed `CONFIG_DATA`
- `${name}_configure` — explicit prompt flow (`nds_cfg_ask_*`)
- `${name}_prompt_errors` — wizard: only prompts fields that fail validation
- `${name}_summary` — menu summary lines
- `${name}_validate` — cross-field checks
- `NDS_PRESET_PRIORITY` / `NDS_PRESET_DISPLAY` at file end (registry calls `nds_preset_register`)

Logic lives in configure/validate functions; types and defaults stay in the preset file.

## Tests

`bootstrap/tests/suites/configurator.sh` and `suites/inputs.sh` (validators in `validate.sh`).
