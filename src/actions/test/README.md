# Test action

Runs NDS self-tests from the live menu when `NDS_TEST=true`.

## Suites (read-only — no system changes)

| Suite | What it checks |
|-------|----------------|
| `cfg` | Presets registered and enabled |
| `inputs` | Field validators (`src/tests/specs/inputs/`) |
| `classicConfig` | `configuration.nix` generation to a temp dir |

## Run without the menu

```bash
bash src/tests/run.sh
```

CI runs the same command on every push.
