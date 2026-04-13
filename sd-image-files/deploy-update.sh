#!/bin/bash
# Deploy container update on Orcanode Pi
# Usage: deploy-update.sh [IMAGE_TAG]

set -e

export IMAGE_TAG="${1:-latest}"

cd /home/pi/orcanode/node

echo "======================================"
echo "  Deploying Orcanode Update"
echo "======================================"
echo "Hostname: $(hostname)"
echo "Image tag: ${IMAGE_TAG}"
echo ""

# Pull latest image
echo "Pulling container image..."
docker compose pull

# Restart with new image
echo "Restarting containers..."
docker compose up -d

# Show status
echo ""
echo "✓ Deployment complete!"
echo ""
docker compose ps