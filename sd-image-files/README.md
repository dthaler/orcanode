# SD Card Image — Workflows

This directory contains the support files used by the
[Build SD Card Image](.github/workflows/build-sd-image.yml) CI workflow to
create a ready-to-run Raspberry Pi OS image for an Orcasound hydrophone node.

The SD card image and the orcanode container image are **decoupled**:

- The **SD card image** defines the infrastructure (OS, Docker, first-boot
  scripts, remote-access agents).
- The **container image** (`ghcr.io/.../orcanode`) defines the application code.

This means container updates can be deployed fleet-wide in minutes without
ever reflashing an SD card.

---

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `PI_PASSWORD` | Default password for the `pi` account. If not set the factory default password is left unchanged. |
| `DATAPLICITY_TOKEN` | Token from the Dataplicity dashboard used to register the device on first boot. If not set, Dataplicity is not configured. |
| `SOCKETXP_AUTH_TOKEN` | Auth token for SocketXP remote-access tunnel. If not set, the SocketXP install step is skipped. |

---

## Deployment Overview

```
Flash SD card → Boot Pi → install-orcanode.sh runs
              → Creates docker-compose.yml pointing to ghcr.io/.../orcanode:latest

Developer pushes code → build-container.yml runs
                      → Pushes ghcr.io/.../orcanode:latest

Admin triggers update:
  → docker compose pull   (downloads new :latest)
  → docker compose up -d  (restarts with new image)
```

---

## First-Install Workflow (infrequent)

### 1 — Build the SD card image

The [build-sd-image.yml](.github/workflows/build-sd-image.yml) workflow runs
automatically on every pull request and can also be triggered manually via
**Actions → Build SD Card Image → Run workflow**.

What the workflow does:

1. Downloads the latest Raspberry Pi OS Lite 32-bit image (64-bit kernel,
   32-bit armhf userland — Bookworm).
2. Expands the image to 8 GB and grows the root partition to match.
3. Mounts the image and customises it inside a chroot:
   - Enables SSH by default (`/boot/ssh`).
   - Optionally sets the `pi` user password (`PI_PASSWORD` secret).
   - Installs Docker (CE, CLI, Compose plugin).
   - Installs the Mezmo (LogDNA) logging agent.
   - Installs SocketXP for remote access (`SOCKETXP_AUTH_TOKEN` secret).
   - Writes a first-boot script for Dataplicity registration
     (`DATAPLICITY_TOKEN` secret).
   - Writes a first-boot script that clones the orcanode repository.
   - Installs the `orcanode-update` helper at `/usr/local/bin/orcanode-update`.
   - Configures a crontab for the `pi` user to start and daily-restart the
     container.
4. Cleans the machine-id so each flashed card gets a unique identity on boot.
5. Compresses the image and:
   - For **pull request / dev builds**: uploads it as the `raspios-orcanode-dev`
     artifact (retained for **7 days**).
   - For **tagged releases** (`v*.*.*`): publishes a GitHub Release with the
     compressed image attached permanently.

### 2 — Flash the image to an SD card

1. Download the image:
   - **PR/dev builds**: download the `raspios-orcanode-dev` artifact from the
     GitHub Actions run (available for 7 days).
   - **Tagged releases**: download the `.img.gz` asset from the
     [GitHub Releases page](../releases) for the desired version tag.
2. Flash it to a microSD card (32 GB or larger):
   - **Raspberry Pi Imager** (recommended): choose *Use custom image* and
     select the downloaded `.img.gz` file.
   - **`dd`** (Linux/macOS):
     ```bash
     gzip -d raspios-orcanode.img.gz
     sudo dd if=raspios-orcanode.img of=/dev/sdX bs=4M status=progress conv=fsync
     ```
     Replace `/dev/sdX` with the correct device for your SD card (use `lsblk`
     to identify it).

### 3 — First boot

Insert the SD card into the Raspberry Pi and power it on.
On first boot the following happens automatically:

| Service | What it does |
|---------|-------------|
| Raspberry Pi OS resize | Expands the root partition to fill the entire SD card. |
| `install-orcanode.service` | Clones `https://github.com/orcasound/orcanode` to `/home/pi/orcanode` and writes a `docker-compose.yml` that pulls the container image from GHCR. Runs only once (condition: `/home/pi/orcanode` does not exist). |
| `install-dataplicity.service` | Runs `/usr/local/sbin/install-dataplicity.sh` to register the device with Dataplicity, then self-disables. Requires `DATAPLICITY_TOKEN` to have been set at build time. |
| `install-socketxp.service` | Runs `/usr/local/sbin/install-socketxp.sh` to install and configure the SocketXP remote-access agent, then self-disables. Requires `SOCKETXP_AUTH_TOKEN` to have been set at build time. |
| `cron` (`@reboot`) | After a 60-second delay, starts the orcanode container via `docker compose up -d`. |

SSH is available immediately after boot on port 22 with user `pi` and the
password set at build time (or the Raspberry Pi OS default if no secret was
provided).

### 4 — Configure the node

Before streaming, create `/home/pi/orcanode/node/.env` with the node-specific
settings (see the root `README.md` for a full example):

```bash
NODE_NAME=rpi_your_location
AUDIO_HW_ID=pisound   # or the name reported by `arecord -l`
CHANNELS=1
SAMPLE_RATE=48000
AWSACCESSKEYID=...
AWSSECRETACCESSKEY=...
```

Restart the container after creating the file:

```bash
cd /home/pi/orcanode/node
docker compose up -d
```

---

## Container Update Workflow (frequent)

Code changes are deployed to all Pis by updating the container image — no SD
card reflashing required.

### Step 1 — Build a new container image

The [build-container.yml](.github/workflows/build-container.yml) workflow runs
automatically whenever code in `node/` or `Dockerfile` is pushed to `main`.
It builds a multi-arch image (`amd64`, `arm/v7`, `arm64`) and pushes it to
GHCR with the `latest` tag (plus a `main-<sha>` tag for traceability).

### Step 2 — Deploy to Pis

**Option A — Manual update (single Pi)**

SSH into the Pi and run the helper script:

```bash
ssh pi@raspberrypi.local
orcanode-update
```

The script shows the currently running version, pulls the latest image from
GHCR, and prompts before restarting the container.

Or run the Docker Compose commands directly:

```bash
cd /home/pi/orcanode/node
docker compose pull
docker compose up -d
```

**Option B — Fleet-wide deployment**

Trigger the [deploy-fleet.yml](.github/workflows/deploy-fleet.yml) workflow
via **Actions → Deploy to Orcanode Fleet → Run workflow**. Choose the target
(`canary`, `production`, or `all`) and optionally specify an image tag.

The workflow SSHes into each Pi and runs `docker compose pull && docker compose up -d`.
The `canary` target runs first; `production` waits for it to stabilise before
rolling out to all production Pis in parallel.

**Option C — Pin to a specific version**

```bash
ssh pi@raspberrypi.local
export IMAGE_TAG=v1.2.3
docker compose -f ~/orcanode/node/docker-compose.yml pull
docker compose -f ~/orcanode/node/docker-compose.yml up -d
```

Available image tags: `latest` (default), semver release tags (e.g. `v1.2.3`),
and `main-<sha>` commit-level tags.

### Automatic nightly restart

The `pi` crontab contains:

```cron
0 0 * * * /usr/bin/docker compose -f /home/pi/orcanode/node/docker-compose.yml down \
           && /usr/bin/docker compose -f /home/pi/orcanode/node/docker-compose.yml up -d
```

Every night at midnight the container is stopped and restarted with the
currently pulled image. To pick up a newer image, run `orcanode-update` (or
use the fleet deploy workflow) before the midnight restart, or pull manually
with `docker compose pull` first.

---

## When to Update SD Card vs Container

### Update the container only (frequent)

- Code changes, dependency updates, bug fixes, feature additions.

How: push to `main` → `build-container.yml` rebuilds `:latest` → deploy via
`orcanode-update` or the fleet deploy workflow (the nightly cron restarts the
container but does not pull).

### Rebuild the SD card image (infrequent)

- OS security patches (suggested: monthly rebuild).
- Docker or system-package updates.
- Changes to first-boot scripts or systemd services.
- New remote-access or logging agent configuration.
- Wi-Fi / network configuration changes.

How: trigger `build-sd-image.yml` → download artifact → flash new deployments.
Existing Pis keep running and do **not** need to be reflashed unless you want
the OS-level changes on them.

---

## Example Timeline

```
Day 1:  Flash SD card (built from main at v1.0.0)
        └─ Pi pulls ghcr.io/.../orcanode:latest (currently v1.0.0)

Day 5:  Developer pushes new feature to main
        └─ build-container.yml runs → :latest now points to new code

Day 5 (10 min later): Admin triggers deploy-fleet.yml → all: latest
        └─ All Pis pull new :latest and restart  (NO SD card reflash!)

Day 30: OS security updates available
        └─ Admin triggers build-sd-image.yml → creates updated SD image
        └─ New deployments use the updated image
        └─ Existing Pis keep running (optional: reflash during maintenance)

Day 45: Critical bugfix needed
        └─ Developer pushes fix to main
        └─ build-container.yml runs → :latest updated
        └─ Admin triggers deploy-fleet.yml → all Pis get fix in minutes
```

---

## File Reference

| File | Purpose |
|------|---------|
| `sources.list` | Debian Bookworm apt sources written into the image during build. |
| `raspi.list` | Raspberry Pi apt repository source written into the image during build. |
| `install-orcanode.sh` | Script that clones the repository and sets up `docker-compose.yml` on first boot. |
| `install-orcanode.service` | Systemd unit that runs `install-orcanode.sh` once on first boot. |
| `install-dataplicity.service` | Systemd unit that runs the Dataplicity registration script once on first boot. |
| `install-socketxp.sh` | Script that installs and configures the SocketXP remote-access agent on first boot. |
| `install-socketxp.service` | Systemd unit that runs `install-socketxp.sh` once on first boot. |
| `orcanode-update.sh` | Helper script installed at `/usr/local/bin/orcanode-update` for manual container updates. |
