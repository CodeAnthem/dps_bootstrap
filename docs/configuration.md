# NDS configuration reference

Every NDS setting maps to an environment variable: `NDS_<KEY>`.

Set variables before starting NDS, or paste the export lines printed at the end of configuration.

## Runtime flags (not stored in CONFIG_DATA)

| Variable | Description |
|----------|-------------|
| `NDS_AUTO_CONFIRM` | Umbrella — skip interactive menus and Y/n prompts (`true`) |
| `NDS_ACTION` | Action name — skip action picker (e.g. `installFlake`) |
| `NDS_ACTION_PREVIEW_SKIP` | Skip install preview screen (`true`) |
| `NDS_SKIP_MENU` | Skip configuration category menu when validation passes (`true`) |
| `NDS_CONFIG_CONFIRM_SKIP` | Skip “continue to installation review” (`true`) |
| `NDS_INSTALL_CONFIRM_SKIP` | Skip local install confirmation (`true`) |
| `NDS_REMOTE_CONFIRM_SKIP` | Skip remote install confirmation (`true`) |
| `NDS_GIT_AUTH_SKIP` | Skip interactive git SSH auth wizard (`true`) |
| `NDS_DISK_FORMAT_CONFIRM_SKIP` | Skip destructive disk format confirmation (`true`) |
| `NDS_BACKUP_CONFIRM_SKIP` | Skip backup zip copy confirmation (`true`) |
| `NDS_REBOOT_SKIP` | Skip reboot prompt after install (`true`) |
| `NDS_SCAFFOLD_OVERWRITE_SKIP` | Skip scaffold host-dir overwrite prompt (`true`) |
| `NDS_HARDWARE_OVERWRITE_SKIP` | Skip hardware file overwrite prompt (`true`) |
| `NDS_PREFLIGHT_WARN_SKIP` | Auto-continue past preflight warnings (`true`) |
| `NDS_PROMPTS_SKIP` | Skip generic Y/n prompts (`nds_ask_user_*`) (`true`) |
| `NDS_TEST` | Enable the test action in the action menu (`true`) |
| `NDS_GIT_IMPORT_KEY_PATH` | Path to a private SSH key to import before git auth (USB/scp) |
| `NDS_DEPLOY_KEY_PATH` | Deprecated alias for `NDS_GIT_IMPORT_KEY_PATH` |
| `NDS_GIT_SSH_KEY_USE_QR` | Skip QR prompt on manual path — `true` or `false` |
| `NDS_GIT_SSH_KEY_DISPLAY` | Manual display mode: `qr` or `copy` |
| `NDS_GIT_SESSION_KEY_PATH` | Session private key path (default `/root/.ssh/git-<owner>-key`) |

## CLI flags

| Flag | Effect |
|------|--------|
| `--auto-confirm` | Sets `NDS_AUTO_CONFIRM` and all `NDS_*_SKIP` flags above |
| `--skip-menu` | Sets `NDS_SKIP_MENU` |
| `--action NAME` | Sets `NDS_ACTION` (e.g. `--action installFlake`) |

---

## installFlake / remoteAction

| Key | Env | Export | Description |
|-----|-----|--------|-------------|
| `INSTALL_MODE` | `NDS_INSTALL_MODE` | when set | `local` (live ISO) or `remote` (nixos-anywhere) |
| `REMOTE_TARGET_IP` | `NDS_REMOTE_TARGET_IP` | changed | Target IP when `INSTALL_MODE=remote` |
| `FLAKE_REPO_URL` | `NDS_FLAKE_REPO_URL` | when set | Git SSH/HTTPS URL for remote flake |
| `FLAKE_LOCAL_PATH` | `NDS_FLAKE_LOCAL_PATH` | when set | Local path to flake on live ISO |
| `FLAKE_LOCATION` | `NDS_FLAKE_LOCATION` | never | Derived — use `FLAKE_REPO_URL` or `FLAKE_LOCAL_PATH` |
| `FLAKE_SOURCE` | `NDS_FLAKE_SOURCE` | never | Derived `remote` or `local` |
| `FLAKE_HOST` | `NDS_FLAKE_HOST` | when set | `nixosConfigurations` name |
| `FLAKE_INSTALL_PATH` | `NDS_FLAKE_INSTALL_PATH` | when set | Flake git root on target (default `/mnt/etc/nixos`) |
| `FLAKE_HOST_DIR` | `NDS_FLAKE_HOST_DIR` | when set | Host directory under flake (default `hosts/x86_64-linux`) |
| `FLAKE_HARDWARE_PLACEMENT` | `NDS_FLAKE_HARDWARE_PLACEMENT` | when set | `host-dir`, `flake-root`, or `skip` |

After install, per-repo deploy keys land under `/root/.ssh/nds_deploy_<owner>_<repo>` with  
`nds-git-ssh` + `nds-git.map` so stock `git+ssh://git@github.com/...` flake URLs keep working  
via `GIT_SSH_COMMAND`. Session / account keys stay on the live ISO; only `nds_deploy_*` keys  
are copied to the installed system. NDS also installs `/root/.nds/bin/nds-switch` and  
`/root/.nds/bin/nds-clean` (legacy `/root/bin`). Prefer enabling `services.nds.helpers.enable`  
in the flake so helpers are on PATH after rebuild. Use `nds-switch --self-update` during NDS  
development to refresh scripts from dps_bootstrap without reinstalling. Install-time  
`facter.json` is unstaged and gitignored after the flake build so the checkout stays  
pullable. Structural `mounts.nix` + `boot.nix` are committed (or git-added at install) so  
flake eval always sees root/boot mounts and the bootloader device.

---

## disk

| Key | Env | Hardware | Description |
|-----|-----|----------|-------------|
| `DISK_TARGET` | `NDS_DISK_TARGET` | yes | Target block device (auto-detected) |
| `DISK_STRATEGY` | `NDS_DISK_STRATEGY` | yes | `nds`, `disko`, or `flake` |
| `DISK_FS_TYPE` | `NDS_DISK_FS_TYPE` | yes | Root filesystem type |
| `DISK_SWAP_SIZE_MIB` | `NDS_DISK_SWAP_SIZE_MIB` | yes | Swap size in MiB (`0` = none) |
| `DISK_DISKO_CONFIG` | `NDS_DISK_DISKO_CONFIG` | yes | Path to disko config when strategy is disko |

---

## boot

| Key | Env | Hardware | Description |
|-----|-----|----------|-------------|
| `BOOT_UEFI_MODE` | `NDS_BOOT_UEFI_MODE` | yes | `uefi` or `bios` (auto-detected) |
| `BOOT_LOADER` | `NDS_BOOT_LOADER` | yes | `grub`, `systemd-boot`, or `refind` |

---

## encryption

| Key | Env | Description |
|-----|-----|-------------|
| `ENCRYPTION` | `NDS_ENCRYPTION` | Enable LUKS2 |
| `ENCRYPTION_PASSWORD` | `NDS_ENCRYPTION_PASSWORD` | Unlock with passphrase |
| `ENCRYPTION_PASSWORD_AUTO` | `NDS_ENCRYPTION_PASSWORD_AUTO` | Generate passphrase |
| `ENCRYPTION_PASSWORD_LENGTH` | `NDS_ENCRYPTION_PASSWORD_LENGTH` | Generated passphrase length |
| `ENCRYPTION_KEY` | `NDS_ENCRYPTION_KEY` | Unlock with keyfile |
| `ENCRYPTION_KEY_AUTO` | `NDS_ENCRYPTION_KEY_AUTO` | Generate keyfile |
| `ENCRYPTION_KEY_LENGTH` | `NDS_ENCRYPTION_KEY_LENGTH` | Keyfile size in bytes |
| `ENCRYPTION_KEY_BOOT_DEVICE` | `NDS_ENCRYPTION_KEY_BOOT_DEVICE` | Raw USB device for keyfile |
| `ENCRYPTION_KEY_BOOT_FILE` | `NDS_ENCRYPTION_KEY_BOOT_FILE` | File path on USB |
| `ENCRYPTION_REMOTE_UNLOCK` | `NDS_ENCRYPTION_REMOTE_UNLOCK` | SSH in initrd for remote unlock |
| `ENCRYPTION_REMOTE_SSH_KEY` | `NDS_ENCRYPTION_REMOTE_SSH_KEY` | Public key allowed in initrd |
| `ENCRYPTION_REMOTE_NETWORK` | `NDS_ENCRYPTION_REMOTE_NETWORK` | `dhcp` or static |
| `ENCRYPTION_REMOTE_PORT` | `NDS_ENCRYPTION_REMOTE_PORT` | Initrd SSH port (default `2222`) |

---

## network

| Key | Env | Hardware | Description |
|-----|-----|----------|-------------|
| `NETWORK_HOSTNAME` | `NDS_NETWORK_HOSTNAME` | yes | System hostname |
| `NETWORK_METHOD` | `NDS_NETWORK_METHOD` | yes | `dhcp` or `static` |
| `NETWORK_IP` | `NDS_NETWORK_IP` | yes | Static IPv4 |
| `NETWORK_MASK` | `NDS_NETWORK_MASK` | yes | Subnet mask |
| `NETWORK_GATEWAY` | `NDS_NETWORK_GATEWAY` | yes | Default gateway |
| `NETWORK_DNS_PRIMARY` | `NDS_NETWORK_DNS_PRIMARY` | yes | Primary DNS |
| `NETWORK_DNS_SECONDARY` | `NDS_NETWORK_DNS_SECONDARY` | yes | Secondary DNS |

---

## access

| Key | Env | Description |
|-----|-----|-------------|
| `ACCESS_ADMIN_USER` | `NDS_ACCESS_ADMIN_USER` | Admin username |
| `ACCESS_ADMIN_PASSWORD_AUTO` | `NDS_ACCESS_ADMIN_PASSWORD_AUTO` | Generate admin password |
| `ACCESS_ADMIN_PASSWORD_LENGTH` | `NDS_ACCESS_ADMIN_PASSWORD_LENGTH` | Generated password length |
| `ACCESS_ADMIN_PASSWORD` | `NDS_ACCESS_ADMIN_PASSWORD` | Manual password |
| `ACCESS_ADMIN_SSH_KEY` | `NDS_ACCESS_ADMIN_SSH_KEY` | Admin SSH public key |
| `ACCESS_SUDO_PASSWORD_REQUIRED` | `NDS_ACCESS_SUDO_PASSWORD_REQUIRED` | Require password for sudo |
| `ACCESS_SSH_ENABLE` | `NDS_ACCESS_SSH_ENABLE` | Enable OpenSSH |
| `ACCESS_SSH_PORT` | `NDS_ACCESS_SSH_PORT` | SSH port |
| `ACCESS_SSH_PASSWORD_AUTH` | `NDS_ACCESS_SSH_PASSWORD_AUTH` | Allow password SSH login |

---

## region / quick / platform / security

See preset defaults in `src/settings/builtin/`. Keys follow the same `NDS_<KEY>` pattern.

---

## Remote flake preset injection

After cloning a flake, NDS loads optional preset hooks from:

| Path | Purpose |
|------|---------|
| `.nds/preset.sh` | Single extra preset (preset id = filename without `.sh`) |
| `.nds/presets/*.sh` | Multiple presets |

Each file uses the same hook contract as builtins: `{id}_defaults`, `{id}_configure`, `{id}_validate`, `{id}_summary`, plus `NDS_PRESET_PRIORITY` and `NDS_PRESET_DISPLAY`.

Extra paths before the action runs (no flake clone needed):

| Env | Purpose |
|-----|---------|
| `NDS_PRESET_EXTRA_DIR` | Directory of `.sh` preset files |
| `NDS_PRESET_EXTRA_PATHS` | Colon-separated preset files or directories |

Actions may also implement `action_presets_paths()` to print extra paths (one per line).

See `src/tests/fixtures/nds-remote-preset.sh` for a minimal example.

## Headless installFlake example

```bash
export NDS_ACTION=installFlake
export NDS_FLAKE_REPO_URL="git@github.com:ORG/dps_swarm.git"
export NDS_FLAKE_HOST="worker-01"
export NDS_DISK_TARGET="/dev/nvme0n1"
export NDS_GIT_IMPORT_KEY_PATH="/tmp/nds-ssh-key"
# Flip individual SKIP flags to true, or use --auto-confirm for all:
export NDS_SKIP_MENU="false"
export NDS_INSTALL_CONFIRM_SKIP="false"
sudo -E bash src/app/main.sh --auto-confirm
```

### Scoped arrays (preferred export)

Configuration export emits `declare -A NDS_FLAKE=(...)` blocks plus legacy
`export NDS_*=` lines. Associative arrays **cannot** cross `sudo` — save the
export to a file and point NDS at it:

```bash
# /tmp/nds-config.env contains declare -A NDS_FLAKE=(...) etc.
export NDS_SCOPED_CONFIG_FILE=/tmp/nds-config.env
export NDS_ACTION=installFlake
sudo -E bash src/app/main.sh
```

Per-repo git access (URL-keyed):

```bash
declare -A NDS_GIT_METHOD=(
  ['git@github.com:ORG/dps_swarm.git']='account'
)
declare -A NDS_GIT_KEY_PATH=(
  ['git@github.com:ORG/dps_swarm.git']='/tmp/nds-ssh-key'
)
```

After interactive configuration, the **Configuration export** screen lists
scoped blocks, legacy scalars, and menu SKIP flags. Private git auth has **no
skip** — missing access fails hard.

## Operator prepare kit

On your laptop (with `gh` authenticated):

```bash
./dev/operator/prepare-install-kit.sh worker-01
```

Copy `ssh_key` to the live ISO and set `NDS_GIT_IMPORT_KEY_PATH` as above.

## Git auth wizard (interactive)

installFlake runs an **early access gate** (URL → auth → host picker → target)
before the settings manager. When SSH access fails, NDS offers (0 = back):

| Route | Options |
|-------|---------|
| GitHub | import / gh CLI / manual / retry |
| Other forges | import / new (manual) / retry |

QR codes load only on the **manual** register path (not gh).

Non-GitHub hosts skip gh and go straight to manual registration. QR codes are offered only on the manual path. The gh session is cleared after a successful install; on abort you may choose to clear it.
