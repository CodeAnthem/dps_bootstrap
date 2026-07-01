# configurator

Interactive wizard: presets, fields, validation, menu, and `NDS_*` env export.

## Layout

| Path | Role |
|------|------|
| `storage.sh` | Config get/set, export script |
| `var.sh` | Field declarations |
| `preset.sh` | Preset enable/disable/registry |
| `menu.sh` | Interactive menu loop |
| `presets/` | Domain field groups (disk, region, network, …) |
| `inputs/` | Validators co-located by domain (`network/`, `region/`, …) |

Validators live **next to their domain** (group by what it is), not in a separate validation tree.

## Tests

`bootstrap/tests/suites/configurator.sh` and `suites/inputs.sh`.
