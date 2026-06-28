# Trust and verification

NDS runs as **root** on the NixOS live ISO and can **erase disks**. Do not pipe scripts into `bash` without understanding what they do.

## What runs on your machine

| Step | What happens |
|------|----------------|
| **`start.sh`** | Clones or refreshes this repo under `/tmp/<repo-name>`, optionally warns about untracked files, then runs `bootstrap/main.sh` |
| **`bootstrap/main.sh`** | Loads shell libraries, shows the configuration menu, partitions the target disk, and runs `nixos-install` |

This repository contains **no cluster secrets**, no private keys, and no org-specific credentials. LUKS keys and similar material are generated at install time and written to a temporary runtime directory on the live system — you must copy them before reboot.

## Verify before you run

1. **Read the entrypoints** — [`start.sh`](start.sh) and [`bootstrap/main.sh`](bootstrap/main.sh) are short and readable.
2. **Clone without installing** — download only, then inspect:
   ```bash
   curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash -s -- --no-exec
   ls /tmp/dps_bootstrap   # or /tmp/<NDS_REPO_NAME> when using a fork
   ```
3. **Manual steps** — clone with git and run `sudo bash bootstrap/main.sh` yourself when you are satisfied.
4. **CI** — shell scripts are linted with [ShellCheck](https://www.shellcheck.net/) on every push ([workflow](.github/workflows/shellcheck.yml)).

## Forks and renamed repositories

There is **no GitHub variable** available to a `curl | bash` one-liner at runtime. To point at a different remote:

```bash
export NDS_REPO_URL='https://github.com/you/your-fork.git'
curl -sSL https://raw.githubusercontent.com/you/your-fork/main/start.sh | bash
```

When you run `start.sh` from a git checkout, it uses `git remote.origin.url` automatically. You can also set `NDS_REPO_NAME` to change the `/tmp` directory name.

## Supply-chain hygiene

- Prefer cloning over piping when you are unsure.
- Use `--no-exec` to fetch the tree without starting the installer.
- If `start.sh` reports untracked files in `/tmp/<repo>`, treat that as suspicious — the script can offer to delete them before continuing.
