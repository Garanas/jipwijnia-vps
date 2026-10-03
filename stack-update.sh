#!/usr/bin/env bash
# Pulls new images for every service but the vault and restarts what changed. Security fixes for
# Traefik, GoatCounter and the rest arrive as new images under the same tags; unattended upgrades
# do not touch images. setup.sh installs this as /usr/local/bin/stack-update, run on Sunday night
# by stack-update.timer. It only restarts what compose.yaml already describes, so rolling out
# compose.yaml stays manual; the vault is updated by its own deploys (vault-deploy.sh).

set -euo pipefail

cd /opt/vault
mapfile -t services < <(docker compose config --services | grep -vx vault)
docker compose pull --quiet "${services[@]}"
docker compose up -d "${services[@]}"
docker image prune -f >/dev/null
