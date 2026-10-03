#!/usr/bin/env bash
# Updates the vault to the latest image. The forced command of the deploy key that the
# scfa-cs-replay workflow uses (Garanas/scfa-cs-replay, .github/workflows/docker.yml): setup.sh
# installs it root-owned as /usr/local/bin/vault-deploy, and the key's line in
# /home/deploy/.ssh/authorized_keys runs nothing else, whatever the client asks for:
#
#   command="/usr/local/bin/vault-deploy",restrict ssh-ed25519 AAAA... github-deploy
#
# Only the image changes: compose.yaml and .env stay manual on purpose. compose.yaml runs any new
# image non-root, read-only, without capabilities or host access; a changed compose file could
# mount the host, so it is not for a CI key.

set -euo pipefail

# The deploy user is not in the docker group: it runs this script as root through the sudo rule
# that setup.sh installs (/etc/sudoers.d/vault-deploy, this exact path and no arguments).
if [[ $EUID -ne 0 ]]; then
    exec sudo -n /usr/local/bin/vault-deploy
fi
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

cd /opt/vault
docker compose pull --quiet vault
docker compose up -d vault
docker image prune -f >/dev/null
docker compose images vault
