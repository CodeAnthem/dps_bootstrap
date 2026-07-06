#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Operator: prepare install kit (deploy keys + env export)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
# Description:   Generate per-machine deploy key and register on listed GitHub repos
# Usage:         ./prepare-install-kit.sh <hostname> <repo> [repo...]
# Requires:      gh CLI authenticated, ssh-keygen
# ==================================================================================================

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <hostname> <github-repo> [github-repo...]" >&2
    echo "Example: $0 worker-01 CodeAnthem/dps_swarm CodeAnthem/thundercast CodeAnthem/thundercore" >&2
    exit 1
fi

HOST="$1"
shift
REPOS=("$@")
KIT_DIR="$(pwd)/nds-install-kit-${HOST}"
KEY_BASE="${KIT_DIR}/deploy_key"

if ! command -v ssh-keygen &>/dev/null; then
    echo "Error: ssh-keygen not found in PATH" >&2
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI not found — install and authenticate (gh auth login)" >&2
    exit 1
fi

mkdir -p "$KIT_DIR"
chmod 700 "$KIT_DIR"
rm -f "${KEY_BASE}" "${KEY_BASE}.pub"
ssh-keygen -t ed25519 -f "$KEY_BASE" -N "" -C "nds-${HOST}"

for repo in "${REPOS[@]}"; do
    gh repo deploy-key add "${KEY_BASE}.pub" -R "$repo" -t "nds-${HOST}"
    echo "Registered deploy key on ${repo}"
done

cat > "${KIT_DIR}/README.txt" <<EOF
NDS install kit for ${HOST}
===========================

1. Copy deploy_key to the live ISO (USB or scp):
     scp ${KEY_BASE} nixos@<live-ip>:/tmp/nds-deploy-key

2. On the live ISO, before running NDS:
     sudo mkdir -p /root/.ssh && sudo chmod 700 /root/.ssh
     sudo cp /tmp/nds-deploy-key /root/.ssh/id_ed25519
     sudo chmod 600 /root/.ssh/id_ed25519
     eval "\$(ssh-agent -s)" && ssh-add /root/.ssh/id_ed25519

3. Run NDS with env vars (example):
     export NDS_FLAKE_REPO_URL="git@github.com:ORG/REPO.git"
     export NDS_FLAKE_HOST="${HOST}"
     export NDS_DEPLOY_KEY_PATH="/tmp/nds-deploy-key"
     export NDS_SKIP_MENU=true
     sudo -E bash bootstrap/main.sh --auto-confirm

After install the deploy key is also copied to /etc/nixos/secrets/git-deploy-key on the target.

Public key (for reference):
$(cat "${KEY_BASE}.pub")
EOF

chmod 600 "${KEY_BASE}"
echo ""
echo "Install kit ready: ${KIT_DIR}"
echo "  deploy_key       — private key (copy to live ISO)"
echo "  deploy_key.pub   — public key"
echo "  README.txt       — operator steps"
