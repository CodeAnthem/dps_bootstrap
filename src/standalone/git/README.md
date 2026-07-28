# src/standalone/git

Argument-only git helpers. No `CONFIG_DATA`, no `nds_cfg_*`, no NDS UI.

| File | Responsibility |
|------|----------------|
| `url.sh` | Parse / normalize URLs, owner slug from URL |
| `hosts.sh` | Host detection, register URLs, GitHub host keys |
| `probe.sh` | Public probe, bare/key SSH env, clone with explicit key |

Framework code lives in `src/framework/git/` and may wrap these with settings/UI.
