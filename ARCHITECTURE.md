# Architecture — the big picture

NDS is a **live-ISO install orchestrator**. It does not define your system. Your **flake** does. NDS connects bare metal to `nixos-install --flake` with sane defaults for disk, hardware facts, and file placement.

Read this before wondering whether hardware “gets lost on git pull” or whether NDS fights disko.

---

## Roles

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────────┐
│  NDS (this repo)│     │  Your leaf flake │     │  Installed NixOS system │
│  live ISO only  │────▶│  dps_swarm, etc. │────▶│  /opt/flake, /etc/nixos │
└─────────────────┘     └──────────────────┘     └─────────────────────────┘
   disk + hw facts          nixosConfigurations        runtime rebuilds
   no secrets                hosts/, modules              nixos-rebuild
```

| Layer | Owns |
|-------|------|
| **NDS** | Partitioning (or delegate), `nixos-generate-config`, staging flake checkout on disk, install command |
| **Leaf flake** | Hostname, network, timezone, users, services, disko module (if any), sops, cluster logic |
| **Installed system** | Persistent copies of flake + machine-local files |

NDS **never** writes timezone/users/services into your flake today. The old `nixConfigBuilder` path (classic `/etc/nixos`) is retired.

---

## Install pipeline (one workflow)

There is only **one** user-facing workflow: answer the menu → confirm → install. Internally:

```
1. Disk strategy (menu: Disk)
2. Stage flake on target disk (menu: Your flake)
3. Hardware facts (generated + placed per HARDWARE_PLACEMENT)
4. Optional machine.nix (LUKS UUID when encryption + host-dir)
5. nixos-install --flake <path>#<host>
```

No wrapper flake. NDS clones **your** repo to e.g. `/mnt/opt/your-leaf` and installs that tree.

---

## Disk strategies

| Strategy | Who partitions | When to use |
|----------|----------------|-------------|
| **nds** (default) | NDS — simple GPT: EFI + root, optional LUKS | Thundercast-style leaves without disko in the flake (e.g. dps_swarm lab VMs) |
| **disko** | NDS — runs [Disko](https://github.com/nix-community/disko) via built-in template or `DISKO_CONFIG` path | Richer layouts (btrfs, swap, separate boot) without putting disko in the flake yet |
| **flake** | **Your flake** — NDS does not partition | Flake defines disko; you mount `/mnt` first (run disko from flake on live ISO) |

**History:** `bootstrap/lib/partitionTools/` (disko + manual fast path) existed before the simplified `nixInstaller/disk.sh`. Disko support is **restored**; default remains `nds` for compatibility with existing host stubs (`/dev/disk/by-label/nixos`).

**Conflict rule:** Do not use `nds` or `disko` if your flake **also** runs disko on the same disk during install. Pick **one** owner.

---

## Hardware configuration — the confusing part

### What is `hardware-configuration.nix`?

Machine-specific facts: kernel modules, device IDs, generated filesystem entries. **Not** the same as `configuration.nix`. Created by:

```bash
nixos-generate-config --root /mnt --show-hardware-config
```

### Placement modes (menu: Your flake → Hardware configuration)

| Mode | Where it lives after install | Git | Typical flake pattern |
|------|------------------------------|-----|------------------------|
| **host-dir** (default) | `<flake>/hosts/.../<host>/hardware-configuration.nix` on disk | **Gitignored** in leaf `.gitignore` | `imports = [ ./hardware-configuration.nix ]` with `pathExists` fallback to eval stub |
| **etc-nixos** | `/etc/nixos/hardware-configuration.nix` only | Outside git checkout | Flake exposes `hardware` input; install/rebuild uses `--override-input hardware path:/etc/nixos/hardware-configuration.nix` |
| **skip** | Not generated/copied by NDS | — | Flake uses eval stub, QEMU guest profile, or pure disko |

### “Will git pull delete my hardware file?”

**No**, if you use **host-dir** correctly:

1. Leaf repo `.gitignore` lists `hardware-configuration.nix` (and `machine.nix`).
2. File exists only on the **installed machine’s disk copy** of the flake.
3. `git pull` updates **tracked** files only — ignored files stay on disk.
4. `nixos-rebuild --flake .#host` keeps using the local hardware file.

**You lose hardware facts only if you:** `git clean -fdx`, delete the host directory, or re-clone over the install path without backing up.

**NDS does not commit hardware to GitHub.** Read-only clone tokens are fine.

### CI vs metal (dps_swarm pattern)

```nix
imports = [
  (if builtins.pathExists ./hardware-configuration.nix
   then ./hardware-configuration.nix
   else ../../../host-lib/eval-boot.nix)
];
```

- **`nix flake check` in CI:** no hardware file → eval stub (QEMU-ish).
- **After NDS install:** real hardware file on disk → real modules and filesystems.

### `machine.nix` (optional)

When encryption is on, NDS can write `machine.nix` with the LUKS partition UUID (also gitignored). The flake profile must already know how to consume `opts.nixos.security.luks`.

---

## What NDS should / should not do

### In scope (stable)

- Guided disk prep (`nds` | `disko` | `flake`)
- Hardware generation + placement
- Flake staging (remote clone / local copy)
- `nixos-install --flake`
- LUKS key generation + backup reminder
- `NDS_*` export block for repeat installs

### Out of scope (by design)

- Generating flake hosts or `nixosConfigurations` from menu
- Applying timezone/network/users from menu to the flake
- Holding cluster secrets or org-specific defaults
- Replacing your flake’s disko module when strategy is `flake`

A future **flake scaffold** tool could create `hosts/<host>/` trees; that is a separate concern from install orchestration.

---

## Manual install comparison

**GUI installer:** classic config in `/etc/nixos`, no flake.

**Expert manual flake:**

```bash
# partition + mount (or disko from flake)
git clone <url> /mnt/opt/leaf
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/opt/leaf/hosts/x86_64-linux/myhost/hardware-configuration.nix
nixos-install --root /mnt --flake /mnt/opt/leaf#myhost
```

NDS is that script sequence with validation, confirmations, and exportable settings.

---

## Choosing settings (cheat sheet)

| Your flake | Disk strategy | Hardware placement |
|------------|---------------|-------------------|
| Thundercast leaf, simple VM | `nds` | `host-dir` |
| Want btrfs/swap via Disko, no flake disko yet | `disko` | `host-dir` |
| Flake owns disko | `flake` (mount `/mnt` first) | `host-dir` or `skip` |
| Legacy flake with `hardware` input | `nds` or `disko` | `etc-nixos` |
| QEMU / test stub only | `nds` | `skip` |

---

## Related docs

- [README.md](README.md) — quickstart
- [LIMITATIONS.md](LIMITATIONS.md) — edge cases and gaps
- [actions/installFlake/README.md](actions/installFlake/README.md) — menu fields
