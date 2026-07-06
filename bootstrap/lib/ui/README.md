# bootstrap/lib/ui

Console primitives only — no action logic, no confirm screens.

Loaded directly by `core/bootstrap.sh`:

- `terminal.sh` — layout, colors, TTY helpers
- `output.sh` — log, warn, error, section headers
- `stepAnimation.sh` — install step UI
- `prompts.sh` — low-level read helpers

Confirm screens live in `core/menus/`.
