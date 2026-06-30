# Nix Deploy System (NDS)

[![Version](https://img.shields.io/badge/version-4.0.2-0267c1?style=flat-square)](https://github.com/CodeAnthem/dps_bootstrap)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![ShellCheck](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml)
[![Self-test](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/selftest.yml/badge.svg)](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/selftest.yml)

**NDS is the guided NixOS installer for the live ISO** — pick a path, answer the menu, and it handles disk prep, hardware facts, staging, and `nixos-install` in order.

**NDS can:**

- Install with **no flake** — generates `/etc/nixos/configuration.nix` (`classicInstall`)
- Install from **your flake** — clone, place hardware facts, `nixos-install --flake` (`installFlake`)
- Run a **custom install script** from your repo — `.nds/action.sh` (`remoteAction`)
- Partition with NDS layouts, **Disko**, or defer to your flake
- Print a **saved `NDS_*` config** you can reuse on the next machine

**NDS does not:**

- Ship your system configuration or secrets
- Replace your flake as the source of truth
- Wrap your flake in another flake
- Commit `hardware-configuration.nix` to your repo (it stays gitignored on disk)

---

## Install paths

| Path | Action | You need |
|------|--------|----------|
| **A** — first install, no flake | `classicInstall` | Live ISO + `nixos` user (sudo) |
| **B** — existing flake | `installFlake` | `nixosConfigurations.<host>`, Git SSH for private repos |
| **C** — custom leaf flow | `remoteAction` | Same as B + `.nds/action.sh` ([API](actions/remoteAction/README.md)) |

---

## Quickstart

### 1. Boot the live ISO

Download the [NixOS minimal ISO](https://nixos.org/download/), boot the target machine or VM, log in as **`nixos`** (passwordless on the console).

### 2. Remote shell (optional)

Use the live console, or SSH from **Linux, macOS, Windows 10+ (OpenSSH), or WSL**:

```bash
passwd               # on the live system — set a password for nixos
ip -4 a              # note the IP
ssh nixos@<ip>       # from your PC
```

### 3. Run NDS

Read [TRUST.md](TRUST.md) before piping a remote script into `bash`.

**Option A — one-liner** (downloads `start.sh`, clones to `/tmp`, runs the menu):

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

**Option B — clone and run** (inspect the repo first):

```bash
git clone https://github.com/CodeAnthem/dps_bootstrap.git /tmp/dps_bootstrap
cd /tmp/dps_bootstrap
sudo bash bootstrap/main.sh    # nixos user — NDS re-execs with sudo if needed
```

Fork or offline? Set `NDS_REPO_URL` before the one-liner, or clone your fork in option B. See [TRUST.md](TRUST.md).

### 4. Import a saved config (optional)

Skip re-entering the menu by **exporting `NDS_*` variables** before step 3:

- **From a previous install** — when you press **X** in the menu, NDS prints an `export NDS_…` block. Save it. Paste or `source` that file before running NDS again.
- **From the template** — copy [`config-example.sh`](config-example.sh), edit values, then `source config-example.sh` before `bootstrap/main.sh`.

Any `NDS_<FIELD>` overrides the matching menu field (same names as the backup export). Example for a flake install:

```bash
source ./my-install.env    # or paste exports directly into the shell
sudo bash bootstrap/main.sh
```

| Variable | Purpose |
|----------|---------|
| `NDS_<FIELD>` | Preset any menu field |
| `NDS_AUTO_CONFIRM=true` | Skip yes/no prompts |
| `NDS_REPO_URL` / `NDS_REPO_NAME` | Point `start.sh` at a fork or different clone path |
| `DEBUG=1` | Verbose logging |

### 5. Pick an action

| Action | When |
|--------|------|
| **classicInstall** | First NixOS install, no flake yet |
| **installFlake** | Generic `nixos-install --flake` |
| **remoteAction** | Your repo ships `.nds/action.sh` (e.g. dps_swarm) |

Then: walk the menu (or rely on your `NDS_*` imports) → press **X** → optionally save the export block (or get it in the final zip) → confirm the destructive step → install → back up the install package → reboot manually.

Logs on the live system: `/tmp/nds_install.log` (verbose nix install output), `/tmp/nds_session.log` (NDS session events).

### 6. Back up install package

After install, NDS creates a zip in `/home/nixos/` (owned by the `nixos` user so `scp`/`ssh` work). It includes your NDS config export, generated configs, install logs, and LUKS keys when encryption was enabled.

NDS prints the full path and copy commands with your machine's IP — paste one of these from a **second terminal** on your PC:

```bash
# Example — use the exact path and IP NDS shows on screen
scp nixos@192.168.1.50:/home/nixos/nds_install_backup_20260629_225213_myhost.zip .

ssh nixos@192.168.1.50 "cat /home/nixos/nds_install_backup_20260629_225213_myhost.zip" > nds_install_backup_20260629_225213_myhost.zip
```

NDS does not reboot automatically when encryption is enabled — reboot only after the package is safe offline.

---

## What happens under the hood

**Classic install (no flake):**

```
Live ISO → menu → disk prep → configuration.nix + hardware-configuration.nix → nixos-install
```

**Flake install:**

```
Live ISO → menu → disk prep (or skip if flake owns disko)
         → nixos-generate-config → stage flake → hardware in host dir
         → nixos-install --flake <path>#<host>
```

NDS clones your flake **directly** — no wrapper flake. Install-time files (`hardware-configuration.nix`, optional `machine.nix` for LUKS) are gitignored on disk.

---

## For flake maintainers

Link here from your leaf README for live-ISO installs. For custom flows, ship `.nds/action.sh` and tell users to pick **remoteAction**.

---

## Develop

```bash
bash scripts/shellcheck.sh              # lint (installs ShellCheck to ~/.cache if needed)
bash scripts/selftest.sh                # read-only self-tests
DEBUG=1 sudo bash bootstrap/main.sh
NDS_TEST=true sudo bash bootstrap/main.sh   # self-test action only
```

Contributor notes: [bootstrap/README.md](bootstrap/README.md) · [bootstrap/lib/README.md](bootstrap/lib/README.md) · [actions/remoteAction/README.md](actions/remoteAction/README.md)
