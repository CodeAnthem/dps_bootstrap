# Nix Deploy System (NDS)

[![Version](https://img.shields.io/badge/version-4.0.1-0267c1?style=flat-square)](https://github.com/CodeAnthem/dps_bootstrap)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![ShellCheck](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml)

**Installing NixOS from your own flake on bare metal is a long checklist.** On the live ISO you partition disks, set up encryption, generate hardware facts, get your flake onto the machine, put files in the right host folder, and run `nixos-install --flake` — in order, without wiping the wrong disk.

**NDS is the guided installer that runs that pipeline for you.** You point it at your flake and host name; it handles disk prep (optional), hardware facts, staging the flake on disk, and the install command. **Your flake stays the source of truth** — NDS does not ship your system config or secrets.

---

## Before you start

You need:

- A **NixOS live ISO** on the target machine or VM
- A **flake** that already defines `nixosConfigurations.<hostname>`
- A **host entry** your flake can import (often `hosts/<system>/<hostname>/` — Thundercast-style layouts work well)
- **Git access** to the flake if installing from a remote private repo (SSH keys on the live system)

NDS is **not** a flake generator. It does not set timezone, users, or services — that lives in your flake. See [ARCHITECTURE.md](ARCHITECTURE.md) for disk strategies, hardware placement, and what happens after install.

---

## Quickstart

### 1. Boot the live ISO

Download the [NixOS minimal ISO](https://nixos.org/download/), boot, log in as **root** on the console.

### 2. SSH from another machine (optional)

On the live system:

```bash
passwd          # required before root can SSH in
ip -4 a         # note the LAN address, e.g. 192.168.1.50
```

**Linux or macOS:**

```bash
ssh root@192.168.1.50
```

**Windows (PowerShell)** — built-in OpenSSH on Windows 10/11; install *OpenSSH Client* under Optional features if `ssh` is missing:

```powershell
ssh root@192.168.1.50
```

Or use the VM **console** and skip SSH entirely.

### 3. Run NDS

**One-liner** (downloads to `/tmp`, then opens the menu):

See [TRUST.md](TRUST.md) before piping a remote script into `bash`.

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

**Fork or renamed repo:**

```bash
export NDS_REPO_URL='https://github.com/you/your-repo.git'
curl -sSL https://raw.githubusercontent.com/you/your-repo/main/start.sh | bash
```

**Manual steps** (clone yourself, no pipe):

```bash
git clone https://github.com/CodeAnthem/dps_bootstrap.git
cd dps_bootstrap
sudo bash bootstrap/main.sh
```

### 4. Install

1. Walk through the menu: **your flake** (URL or local path, host name) and **disk** (target device, encryption).
2. Press **X** to confirm — save the printed `NDS_*` lines if you may repeat this install.
3. Confirm the destructive step when prompted.
4. Back up **runtime secrets** (LUKS key, if enabled), then reboot.

---

## What happens under the hood

```
  Live ISO
     │
     ▼
  Menu (flake + disk options)
     │
     ▼
  Disk prep (NDS layout) ── or skip if your flake owns partitioning
     │
     ▼
  nixos-generate-config  →  hardware-configuration.nix
     │
     ▼
  Stage your flake on disk  (git clone or copy)
     │
     ▼
  Copy hardware-configuration.nix into host dir  (optional skip)
     │
     ▼
  nixos-install --flake <path>#<host>
```

Your flake is cloned/copied **directly** — there is no wrapper flake. NDS only adds install-time files (`hardware-configuration.nix`, optional `machine.nix` for LUKS UUID) under your host directory.

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

Leaf repos (e.g. Thundercast consumers) can link to this project for live-ISO installs and document which `nixosConfigurations` host name and repo URL to use.

---

## Develop

```bash
DEBUG=1 sudo bash bootstrap/main.sh
NDS_TEST=true sudo bash bootstrap/main.sh   # configurator test harness only
```

Contributor notes: [bootstrap/README.md](bootstrap/README.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [LIMITATIONS.md](LIMITATIONS.md)
