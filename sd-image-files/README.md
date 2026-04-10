# SD Card Image — Workflows

This directory contains the support files used by the
[Build SD Card Image](.github/workflows/build-sd-image.yml) CI workflow to
create a ready-to-run Raspberry Pi OS image for an Orcasound hydrophone node.

---

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `PI_PASSWORD` | Default password for the `pi` account. If not set the factory default password is left unchanged. |
| `DATAPLICITY_TOKEN` | Token from the Dataplicity dashboard used to register the device on first boot. If not set, Dataplicity is not configured. |
| `SOCKETXP_AUTH_TOKEN` | Auth token for SocketXP remote-access tunnel. If not set, the SocketXP install step is skipped. |

---

## First-Install Workflow

### 1 — Build the SD card image

The CI workflow runs automatically on every pull request and can also be
triggered manually via **Actions → Build SD Card Image → Run workflow**.

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
5. Compresses the image and uploads it as the `raspios-orcanode` artifact
   (retained for 1 day).

### 2 — Flash the image to an SD card

1. Download the `raspios-orcanode` artifact (a `.img.gz` file) from the
   GitHub Actions run.
2. Flash it to a microSD card (32 GB or larger):
   - **Raspberry Pi Imager** (recommended): choose *Use custom image* and
     select the downloaded `.img.gz` file.
   - **`dd`** (Linux/macOS):
     ```bash
     gzip -d raspios-orcanode.img.gz
     sudo dd if=raspios-orcanode.img of=/dev/sdX bs=4M status=progress conv=fsync
     ```
     Replace `/dev/sdX` with the correct device for your SD card.

### 3 — First boot

Insert the SD card into the Raspberry Pi and power it on.
On first boot the following happens automatically:

| Service | What it does |
|---------|-------------|
| Raspberry Pi OS resize | Expands the root partition to fill the entire SD card. |
| `install-orcanode.service` | Clones `https://github.com/orcasound/orcanode` to `/home/pi/orcanode` and writes a `docker-compose.yml` that pulls the container image from GHCR. Runs only once (condition: `/home/pi/orcanode` does not exist). |
| `install-dataplicity.service` | Runs `/usr/local/sbin/install-dataplicity.sh` to register the device with Dataplicity, then self-disables. Requires `DATAPLICITY_TOKEN` to have been set at build time. |
| `clear-socketxp.service` | Wipes the SocketXP identity (`/var/lib/socketxp/`) so the device registers as a new unique device, then self-disables. |
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

## Deploying a New Container Image

### Automatic (daily)

The `pi` crontab contains:

```cron
0 0 * * * /usr/bin/docker compose -f /home/pi/orcanode/node/docker-compose.yml down \
           && /usr/bin/docker compose -f /home/pi/orcanode/node/docker-compose.yml up -d
```

Every night at midnight the running container is stopped, the latest image is
pulled from GHCR, and a fresh container is started.

### Manual

SSH into the Pi and run the helper script:

```bash
orcanode-update
```

The script shows the currently running version, pulls the latest image, and
prompts before restarting the container.

Alternatively, run the Docker Compose commands directly:

```bash
cd /home/pi/orcanode/node
docker compose pull
docker compose up -d
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
| `clear-socketxp.service` | Systemd unit that wipes the SocketXP identity on first boot so the device registers as new. |
| `orcanode-update.sh` | Helper script installed at `/usr/local/bin/orcanode-update` for manual container updates. |
