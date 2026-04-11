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

# Create docker-compose.yml that pulls from registry with logspout sidecar
# IMAGE_TAG defaults to 'latest' for automatic updates
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  streaming:
    image: ghcr.io/orcasound/orcanode/orcanode:${IMAGE_TAG:-latest}
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/snd:/dev/snd
    environment:
      - NODE_NAME=${NODE_NAME:-orcanode}
      - SAMPLE_RATE=${SAMPLE_RATE:-48000}
      - AUDIO_HW_ID=${AUDIO_HW_ID:-pisound}
      - CHANNELS=${CHANNELS:-1}
      - FLAC_DURATION=${FLAC_DURATION:-30}
      - SEGMENT_DURATION=${SEGMENT_DURATION:-10}
      - AWS_METADATA_SERVICE_TIMEOUT=${AWS_METADATA_SERVICE_TIMEOUT:-5}
      - AWS_METADATA_SERVICE_NUM_ATTEMPTS=${AWS_METADATA_SERVICE_NUM_ATTEMPTS:-0}
      - REGION=${REGION:-us-west-2}
      - BUCKET_TYPE=${BUCKET_TYPE:-dev}
      - NODE_TYPE=${NODE_TYPE:-hls-only}
      - AWSACCESSKEYID=${AWSACCESSKEYID}
      - AWSSECRETACCESSKEY=${AWSSECRETACCESSKEY}
    volumes:
      - ./config:/config
    network_mode: host
    labels:
      - "logspout.ignore=false"

  logspout:
    image: emdem/raspi-logspout:latest
    restart: unless-stopped
    environment:
      - SYSLOG_URL=${SYSLOG_URL}
      - SYSLOG_STRUCTURED_DATA=${SYSLOG_STRUCTURED_DATA}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "8000:8000"
    labels:
      - "logspout.ignore=true"
COMPOSE

chown pi:pi docker-compose.yml

echo "Orcanode installed successfully"