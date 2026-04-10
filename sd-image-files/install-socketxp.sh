#!/bin/bash
# Install and configure SocketXP on first boot

set -e

SOCKETXP_TOKEN="$1"

if [ -z "$SOCKETXP_TOKEN" ]; then
    echo "No SocketXP auth token provided, skipping installation"
    exit 0
fi

echo "Installing SocketXP..."

# Download and run installer
curl -fsSL https://portal.socketxp.com/download/iot/socketxp_install.sh | bash -s -- -a "$SOCKETXP_TOKEN"

echo "SocketXP installed and configured"