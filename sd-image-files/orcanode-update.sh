#!/bin/bash
# Orcanode Manual Update Script

set -e

cd /home/pi/orcanode/node

echo "======================================"
echo "  Orcanode Update Utility"
echo "======================================"
echo ""

# Get current version
CONTAINER_ID=$(docker compose ps -q orcanode 2>/dev/null || true)
if [ -n "$CONTAINER_ID" ]; then
    CURRENT_TAG=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' "$CONTAINER_ID" 2>/dev/null || echo "unknown")
else
    CURRENT_TAG="unknown"
fi
echo "Current version: $CURRENT_TAG"
echo ""

# Check for available updates
echo "Checking for updates..."
docker compose pull

echo ""
read -p "Deploy the update now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploying update..."
    docker compose up -d
    echo ""
    echo "✓ Update complete!"
    echo ""
    docker compose ps
else
    echo "Update cancelled. Run 'orcanode-update' when ready to deploy."
fi