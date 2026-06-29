# Test action

Runs NDS self-tests from the live menu when `NDS_TEST=true`.

## Suites (read-only — no system changes)

| Suite | What it checks |
|-------|----------------|
| `configurator` | Presets registered and enabled |
| `inputs` | Field validators (`bootstrap/tests/specs/inputs/`) |
| `classicConfig` | `configuration.nix` generation to a temp dir |

## Run without the menu

```bash
bash bootstrap/tests/run.sh
```

CI runs the same command on every push.
