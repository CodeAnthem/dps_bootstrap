# nixosNode — cluster node install

Install a [dps_swarm](https://github.com/CodeAnthem/dps_swarm) host from a NixOS live ISO using `nixos-install --flake`.

---

## Quickstart

### 1. Prepare the live environment

```bash
# On NixOS minimal ISO (as root or via sudo)

# Optional: enable SSH
passwd

# Required for private repo: load your GitHub deploy key
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# copy id_ed25519 + id_ed25519.pub, then:
ssh -T git@github.com
```

### 2. Launch bootstrap

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

Select **nixosNode**.

### 3. Configurator choices

| Preset | What to set |
|--------|-------------|
| **Cluster Node** | `FLAKE_REPO_URL` (default: `git+ssh://git@github.com/CodeAnthem/dps_swarm.git`) |
| | `FLAKE_INSTALL_PATH` (default: `/mnt/opt/dps_swarm`) |
| | `NODE_ROLE` — see table below |
| **Network** | `HOSTNAME` — override to pick `worker-02` / `worker-03` |
| | Static IP fields (used for validation; host IP comes from flake `configuration.nix`) |
| **Disk** | `DISK_TARGET` — e.g. `/dev/vda` in a VM |
| | `ENCRYPTION` — **off** for fastest VM smoke test |
| | `REMOTE_UNLOCK` — on only for `encrypted-worker` role (auto-enabled) |

### 4. Role → flake host

| NODE_ROLE | Default host | Profile |
|-----------|--------------|---------|
| `control-toolkit` | `control-toolkit` | Ops VM — **start here** |
| `gateway` | `gateway-01` | Swarm manager + edge |
| `worker` | `worker-01` | Swarm worker |
| `gpu-worker` | `gpu-worker-01` | GPU worker |
| `encrypted-worker` | `encrypted-worker` | LUKS + remote unlock |

Set **Hostname** in the Network preset to use `worker-02`, `worker-03`, etc.

### 5. Confirm and install

The installer will:

1. Partition and mount `/mnt`
2. Clone the flake onto the target disk
3. Generate `hosts/x86_64-linux/<host>/hardware-configuration.nix`
4. Write `machine.nix` with LUKS UUID when encryption is enabled
5. Run `nixos-install --flake /mnt/opt/dps_swarm#<host>`

### 6. After reboot

| Check | Expected |
|-------|----------|
| Login | `root` / `root` on eval stubs (change immediately) |
| Flake checkout | `/opt/dps_swarm` on installed system |
| LUKS key | Back up from bootstrap runtime dir if encrypted |
| sops | Place age key at `/etc/sops/age/keys.txt` before relying on secrets |

---

## First VM smoke test

Recommended settings:

- Role: **control-toolkit**
- Encryption: **disabled**
- Disk: single virtio disk (`/dev/vda`)
- VM network: `192.168.1.0/24` to match host configs, or edit `hosts/.../configuration.nix` first

---

## Encrypted / production nodes

1. Enable **Encryption** in Disk preset (default on)
2. For remote unlock: enable **REMOTE_UNLOCK** (auto for `encrypted-worker`)
3. Bootstrap generates initrd SSH keys → `/etc/ssh/initrd_ssh_host_ed25519_key`
4. Bootstrap writes `machine.nix` with LUKS device UUID
5. After install: encrypt the LUKS key into sops (`luks/root_key`) and deploy age key to the host

Update `profiles/encrypted-worker.nix` with your SSH public key before installing encrypted workers.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `git clone` fails | SSH key / repo access on live ISO |
| `nixos-install` eval error | Run `nix flake check` on dps_swarm locally; check host `opts.nix` |
| Wrong IP after boot | Edit host `configuration.nix` — bootstrap network preset does not override flake networking |
| sops fails on boot | Install age key; encrypt real secrets in `secrets/secrets.yaml` |
| LUKS won't unlock | Ensure `machine.nix` UUID matches; add `luks/root_key` to sops |

---

## Related

- [dps_swarm README](https://github.com/CodeAnthem/dps_swarm/blob/main/README.md)
- [dps_bootstrap README](../../README.md)
