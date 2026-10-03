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

cd /opt/vault
docker compose pull --quiet vault
docker compose up -d vault
docker image prune -f >/dev/null
docker compose images vault
