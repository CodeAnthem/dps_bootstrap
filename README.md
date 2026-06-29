# Nix Deploy System (NDS)

[![Version](https://img.shields.io/badge/version-4.0.1-0267c1?style=flat-square)](https://github.com/CodeAnthem/dps_bootstrap)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![ShellCheck](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml)

**Installing NixOS on bare metal is a long checklist.** Partition disks, set up encryption, generate hardware facts, stage your config, run `nixos-install` — in order, without wiping the wrong disk.

**NDS is the guided installer.** Pick a path in the menu; it handles disk prep, hardware facts, staging, and the install command. **Your flake or `/etc/nixos` config stays the source of truth** — NDS does not ship your system config or secrets.

---

## Before you start

You need:

- A **NixOS live ISO** on the target machine or VM
- **Root** on the live system (console or SSH after `passwd`)

**Path A — no flake yet (`classicInstall`):** nothing else. The menu collects timezone, network, user, and disk options.

**Path B — existing flake (`installFlake`):**

- A flake with `nixosConfigurations.<hostname>`
- A host entry (often `hosts/<system>/<hostname>/`)
- **Git SSH access** on the live system for private repos

**Path C — leaf with custom install (`remoteAction`):** same as B, plus `.nds/action.sh` in your flake repo (see [actions/remoteAction/README.md](actions/remoteAction/README.md)).

---

## Quickstart

### 1. Boot the live ISO

Download the [NixOS minimal ISO](https://nixos.org/download/), boot, log in as **root**.

### 2. SSH from another machine (optional)

```bash
passwd && ip -4 a    # on the live system
ssh root@<ip>        # Linux/macOS/WSL
```

### 3. Run NDS

See [TRUST.md](TRUST.md) before piping a remote script into `bash`.

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

Or clone and run: `sudo bash bootstrap/main.sh`

### 4. Pick an action

| Action | When |
|--------|------|
| **classicInstall** | First NixOS install, no flake yet |
| **installFlake** | Generic `nixos-install --flake` |
| **remoteAction** | Your repo ships `.nds/action.sh` (e.g. dps_swarm) |

Then: walk the menu → press **X** to confirm → save `NDS_*` export lines → confirm destructive step → back up secrets → reboot.

Install log (survives reboot): `/tmp/nds_install.log`

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

## Repeat the same install

Paste the export block from the menu, or use [`config-example.sh`](config-example.sh):

```bash
export NDS_FLAKE_SOURCE=remote
export NDS_FLAKE_REPO_URL=git+ssh://git@github.com/you/your-leaf.git
export NDS_FLAKE_HOST=my-server
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
sudo bash bootstrap/main.sh
```

| Variable | Purpose |
|----------|---------|
| `NDS_<FIELD>` | Preset any menu field (same names as the backup export) |
| `NDS_AUTO_CONFIRM=true` | Skip yes/no prompts |
| `NDS_REPO_URL` / `NDS_REPO_NAME` | Override repo URL or `/tmp` clone dir for `start.sh` |
| `DEBUG=1` | Verbose logging |

---

## Point your flake README here

Leaf repos can link here for live-ISO installs. For custom flows, ship `.nds/action.sh` and document the **remoteAction** menu entry.

---

## Develop

```bash
DEBUG=1 sudo bash bootstrap/main.sh
NDS_TEST=true sudo bash bootstrap/main.sh   # self-test action only
bash bootstrap/tests/run.sh                 # same tests, no menu
```

Contributor notes: [bootstrap/README.md](bootstrap/README.md) · [bootstrap/lib/README.md](bootstrap/lib/README.md) · [actions/remoteAction/README.md](actions/remoteAction/README.md)
