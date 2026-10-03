# jipwijnia-vps

Configuration of the VPS behind `*.jipwijnia.nl`: one Docker Compose stack with Traefik in front
(HTTPS via Let's Encrypt) and the sites behind it.

| Site | What | Source |
|---|---|---|
| https://vault.jipwijnia.nl | Replay vault for Supreme Commander: Forged Alliance Forever | [Garanas/scfa-cs-replay](https://github.com/Garanas/scfa-cs-replay) (image `ghcr.io/garanas/scfa-cs-replay`) |
| https://stats.jipwijnia.nl | Visitor statistics ([GoatCounter](https://www.goatcounter.com)): no cookies, no personal data | `arp242/goatcounter` |

The server: TransIP VPS (1 vCPU, 1 GB), Ubuntu 26.04 LTS. Plenty: the vault parses replays in the
visitor's browser and only serves files. Measured: Traefik ~30 MB, the vault ~20 MB, GoatCounter ~45 MB.

| File | What |
|---|---|
| `compose.yaml` | The stack: Traefik (HTTP → HTTPS, a certificate per host name) with a read-only Docker socket proxy, the vault, GoatCounter. Lives in `/opt/vault` on the server. |
| `.env.example` | Settings next to `compose.yaml` (`ACME_EMAIL`, host names, `VAULT_IMAGE`). The real `.env` exists only on the server. |
| `setup.sh` | One-time setup of a fresh Ubuntu VPS: admin user, SSH keys only, firewall, automatic updates, swap, Docker, the `deploy` user, `/opt/vault`, weekly image updates. Safe to run again. |
| `vault-deploy.sh` | Pulls the vault image and restarts it; installed as `/usr/local/bin/vault-deploy`, the only command the deploy key may run. |
| `compose.local.yaml` | Override to try the stack on your own machine, without Let's Encrypt. |

**Never commit secrets.** This repository is public: `.env` is gitignored, keys live in GitHub
secrets and on the server only. GitHub push protection is on as a second line.

## Try it locally

```sh
docker compose -f compose.yaml -f compose.local.yaml up -d
# http://vault.localhost, GoatCounter at http://stats.localhost
docker compose -f compose.yaml -f compose.local.yaml down
```

To try an unreleased vault, build it in scfa-cs-replay (`docker build -t scfa-cs-replay:local .`) and
start with `VAULT_IMAGE=scfa-cs-replay:local`.

## First-time server setup

1. **VPS**: install Ubuntu LTS from the TransIP panel with your SSH **public** key. TransIP creates a
   user with passwordless sudo and mails its name (here `willemwijnia`); root login is off.
   On your machine, `~/.ssh/config`:
   ```
   Host vps
       HostName 37.97.229.165
       User willemwijnia
       IdentityFile ~/.ssh/transip-id-ed25519
       IdentitiesOnly yes
   ```
2. **Setup**: `ssh vps`, then
   ```sh
   curl -fsSL https://raw.githubusercontent.com/Garanas/jipwijnia-vps/main/setup.sh -o setup.sh
   sudo bash setup.sh willemwijnia
   ```
   Keep the session open until `ssh vps` works in a second terminal. Log in again before using
   `docker` (the group membership is new), and `sudo reboot` if `/var/run/reboot-required` exists.
3. **DNS** at TransIP: `A` and `AAAA` records for `vault` and `stats` pointing at the VPS
   (`37.97.229.165`, `2a01:7c8:fffd:f5:5054:ff:fe11:fd0d`). Leave `@`, `www` and `MX` alone: the
   website and mail stay where they are.
4. **Stack**: fill in `ACME_EMAIL` in `/opt/vault/.env`, then `cd /opt/vault && docker compose up -d`.
   Traefik requests a certificate per host name on the first HTTPS request.
5. **GoatCounter**: create the site and your account right away, before anyone else can open the
   setup wizard at https://stats.jipwijnia.nl:
   ```sh
   docker compose exec goatcounter goatcounter db create site -vhost=stats.jipwijnia.nl -user.email=<you>
   ```
6. **Deploy key** for the vault: see below.

What `setup.sh` leaves you with: SSH with keys only (`MaxAuthTries 3`, no root, only members of
`sudo` and `deploy`), `ufw` allowing only 22 (rate limited), 80 and 443, unattended upgrades for
Ubuntu and Docker Engine with a reboot at 04:30 when needed, 2 GB swap, container logs capped at
3 × 10 MB, `no-new-privileges` for every container, and `.env` readable only by you and the `docker`
group. Mind that ports published by Docker bypass `ufw`: only Traefik publishes ports; every site is
reached through it.

How the stack is locked down:
- Traefik reads containers through `socket-proxy`, which allows only `GET` on containers and events;
  the Docker socket itself would make a Traefik bug root on the host.
- Each site shares a network only with Traefik, not with the other sites. The networks Traefik is
  published from have IPv6, so IPv6 visitors keep their own address (rate limits, statistics).
- The vault runs as UID 1654, read-only, without capabilities, whatever its image says: the image is
  the part CI can change.
- `stack-update.timer` pulls new Traefik, socket-proxy and GoatCounter images on Sunday at 04:00
  (`systemctl list-timers stack-update`, `journalctl -u stack-update`). Unattended upgrades do not
  touch images. Moving to a new minor version (e.g. `traefik:v3.8`) is a change to `compose.yaml`.

## Changing the stack

Edit `compose.yaml` here, push to `main`, then on the server:

```sh
cd /opt/vault
curl -fsSL https://raw.githubusercontent.com/Garanas/jipwijnia-vps/main/compose.yaml -o compose.yaml
docker compose pull && docker compose up -d
```

This stays manual on purpose: a compose file can mount the host, so it is not for a CI key. A
service that leaves a network behind (e.g. after a rename) needs a `docker network rm vault_<name>`.

## Releasing the vault

Releases come from the scfa-cs-replay repository: `git push origin main:deploy/production` tests,
builds and pushes `ghcr.io/garanas/scfa-cs-replay:latest` and `:sha-<commit>`, then its `deploy` job
connects as the user `deploy` and runs `vault-deploy`: pull the image, restart the vault. Nothing
else. The commit that is live shows in the vault's footer.

Roll back by setting `VAULT_IMAGE=ghcr.io/garanas/scfa-cs-replay:sha-<commit>` in `/opt/vault/.env`
and running `docker compose up -d`; while that pin is in place, deploys keep pulling the pinned image.

### Deploy key (once, or to replace it)

1. A key pair just for GitHub, without a passphrase (on your own machine):
   ```sh
   ssh-keygen -t ed25519 -N "" -C github-deploy -f github-deploy
   ```
2. On the server, restrict the key to that one command. The file must be called exactly
   `authorized_keys`:
   ```sh
   echo 'command="/usr/local/bin/vault-deploy",restrict <contents of github-deploy.pub>' \
       | sudo tee /home/deploy/.ssh/authorized_keys
   ```
3. scfa-cs-replay on GitHub → Settings → Environments → `production` (limited to the
   `deploy/production` branch), three environment **secrets**:
   - `DEPLOY_SSH_KEY`: the contents of `github-deploy` (the private key);
   - `DEPLOY_HOST`: `37.97.229.165`;
   - `DEPLOY_KNOWN_HOSTS`: the output of `ssh-keyscan -t ed25519 37.97.229.165`, after checking its
     fingerprint against `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the server
     (currently `SHA256:U2iklDQJd4lLVa5BtQpqExV1J1wiSnP3a+/j/DBR0mo`).
4. Delete both key files from your machine; GitHub holds the only copy.

Troubleshooting: `Permission denied (publickey)` in the deploy job → on the server,
`sudo journalctl -u ssh --since "30 min ago" | grep deploy` and
`sudo ssh-keygen -lf /home/deploy/.ssh/authorized_keys` (the fingerprints must match).

## Adding a site

Add a service with its own labels and its own network, and add that network to Traefik's
`networks:`; Traefik picks it up and requests its certificate:

```yaml
services:
  traefik:
    networks: [socket, vault, stats, website]

  website:
    image: nginx:alpine
    restart: unless-stopped
    volumes:
      - ./website:/usr/share/nginx/html:ro
    networks: [website]
    labels:
      traefik.enable: "true"
      traefik.http.routers.website.rule: Host(`jipwijnia.nl`) || Host(`www.jipwijnia.nl`)
      traefik.http.routers.website.entrypoints: websecure

networks:
  website:
    enable_ipv6: true
```

Then point its DNS records at the VPS. Never give a site `ports:`; Traefik is the only way in. A
site without a network shared with Traefik gets a `504 Gateway Timeout`.

## Backups

Only the volumes hold state: `goatcounter` (the statistics — worth keeping) and `letsencrypt`
(certificates; Traefik requests new ones if lost). Everything else is in this repository or in an
image. Use TransIP's VPS snapshots/backups.
