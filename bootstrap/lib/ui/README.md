# ui

All console output, terminal layout, and interactive prompts.

Loaded in order by `load.sh` → `nds_ui_load`:

| File | Role |
|------|------|
| `terminal.sh` | Mode detection (`NDS_UI_MODE`), indent, boxes, two-column rows, booleans |
| `output.sh` | `console`, `info`/`warn`/`error`, sections, step progress |
| `prompts.sh` | `nds_askUserContinue`, `nds_askUserToProceed`, legacy `prompt_*` helpers |
| `actions.sh` | `nds_action_items` helper, install warning and confirm screens |

Override terminal behaviour with `NDS_UI_MODE=plain|color|unicode`.
