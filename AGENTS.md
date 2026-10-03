# Agent guide — jipwijnia-vps

Configuration of the VPS behind `*.jipwijnia.nl` (TransIP, Ubuntu 26.04, 37.97.229.165). The README
is the runbook; keep it in step with every change.

- **Public repository: never commit secrets** — no `.env`, keys, tokens or passwords. Settings go in
  `.env.example` with empty or default values; real values live in `/opt/vault/.env` on the server
  and in GitHub secrets.
- The server fetches files from `main` via `raw.githubusercontent.com` (`setup.sh`, the
  `compose.yaml` update in the README): what is on `main` is what the server should run.
- `setup.sh` must stay idempotent and must never lock the admin out: root/password SSH only goes off
  once the admin user has a key and can sudo.
- Only Traefik publishes ports. Sites get Traefik labels and their own network shared with Traefik,
  never `ports:` (Docker bypasses `ufw`). Traefik never gets the Docker socket, only `socket-proxy`.
- Rolling out `compose.yaml` stays manual. The automated paths are the vault's deploy key, forced
  to `vault-deploy` (`vault-deploy.sh`, image pull + restart), and `stack-update.timer` (weekly pull
  of the other images under their existing tags). Don't widen what a CI key can do.
- Shell: bash, `set -euo pipefail`, LF line endings, must pass shellcheck (`.github/workflows/check.yml`).
- An agent cannot SSH in non-interactively (the admin key has a passphrase): give the user the
  commands to run and ask for the output.
