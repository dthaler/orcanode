#!/bin/bash
# Clone orcanode repository on first boot

set -e

echo "Installing Orcanode..."

# Clone repository
cd /home/pi
git clone https://github.com/orcasound/orcanode.git
chown -R pi:pi /home/pi/orcanode

# Update docker-compose.yml to use registry images
cd /home/pi/orcanode/node

# Backup original if it exists
if [ -f docker-compose.yml ]; then
    cp docker-compose.yml docker-compose.yml.bak
fi

# Create docker-compose.yml that pulls from registry
# IMAGE_TAG defaults to 'latest' for automatic updates
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  orcanode:
    image: ghcr.io/orcasound/orcanode/orcanode:${IMAGE_TAG:-latest}
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/snd:/dev/snd
    environment:
      - NODE_NAME=${NODE_NAME:-orcanode}
    volumes:
      - ./config:/config
    network_mode: host
COMPOSE

chown pi:pi docker-compose.yml

echo "Orcanode installed successfully"