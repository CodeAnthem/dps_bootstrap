#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Operator: rotate GitHub deploy key
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-03 | Modified: 2026-07-03
# Description:   Create a new read-only deploy key and register it on a GitHub repo
# Usage:         ./rotate-deploy-keys.sh <hostname> <github-repo>
# Requires:      gh CLI authenticated, ssh-keygen
# ==================================================================================================

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <hostname> <github-repo>" >&2
    echo "Example: $0 worker-01 CodeAnthem/dps_swarm" >&2
    exit 1
fi

HOST="$1"
REPO="$2"
KEY_BASE="/tmp/deploy_${HOST}"

if ! command -v ssh-keygen &>/dev/null; then
    echo "Error: ssh-keygen not found in PATH" >&2
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI not found — install and authenticate (gh auth login)" >&2
    exit 1
fi

rm -f "${KEY_BASE}" "${KEY_BASE}.pub"
ssh-keygen -t ed25519 -f "$KEY_BASE" -N "" -C "deploy-${HOST}"
gh repo deploy-key add "${KEY_BASE}.pub" -R "$REPO" -t "deploy-${HOST}"

echo ""
echo "New deploy key created for ${HOST} on ${REPO}"
echo ""
echo "Copy private key to the machine:"
echo "  scp ${KEY_BASE} root@<machine>:/etc/ssh/deploy_key"
echo ""
echo "Then configure git on the machine to use it (e.g. GIT_SSH_COMMAND or ~/.ssh/config)."
