# bootstrap/_unused

Archived modules — **not loaded** by NDS. Kept in case something external still referenced old paths.

| Path | Was |
|------|-----|
| `lib-config/` | `lib/config/` — shims to settingsManager/validators |
| `lib-nixcfg/` | `lib/nixcfg/` — pre–nixWriter stub |
| `ui-actions.sh` | `lib/ui/actions.sh` — menu shim (menus live in `core/menus/`) |
| `ui-load.sh` | `lib/ui/load.sh` — unused UI loader |
| `lib-install-flake.sh` | `lib/install/flake.sh` — moved to `tools/flake/helpers.sh` |
| `core-install-flake.sh` | `core/install/install.flake.sh` — renamed to `flake-pipeline.sh` |
| `install-compat.sh` | `lib/install/_compat.sh` — run_step / nds_cfg_get_env shims |
| `install-git-access.sh` | `lib/install/git-access.sh` — duplicate git loader |
| `install-orchestration.sh` | `lib/install/orchestration.sh` — split to pipelines + disk-prep |
| `install-bundle.sh` | `lib/install/bundle.sh` — split to `bundle/` |
| `install-detect.sh` | `lib/install/detect.sh` — moved to `tools/install/detect.sh` |

Safe to delete after a release cycle if nothing references these files.
